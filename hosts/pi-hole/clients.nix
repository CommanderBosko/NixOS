# Declarative Pi-hole groups and clients.
#
# Pi-hole keeps groups and clients in gravity.db and the nixpkgs pihole-ftl
# module has no option for them, so this module applies them through the FTL
# API from a boot-time oneshot instead. The client list (friendly names and MAC
# addresses) is private, so it never appears in this public repo: it lives in
# an encrypted secret and only its runtime path is configured here.
#
# The unit authenticates the way the module's own pihole-ftl-setup unit does:
# FTL writes a throwaway CLI password to /etc/pihole/cli_pw on every start
# (webserver.api.cli_pw, which must stay on), and a session opened with it may
# manage lists, groups, clients and domains but not change the FTL config.
#
# Runtime check (a NixOS VM test, since the sandboxed unit needs a real FTL):
# enable pihole-ftl and pihole-web with a web password set (so the API answers
# 401 and the CLI-password login is exercised) and one adlist from a local
# file:// URL (so the setup unit creates gravity.db); write a fake client list
# with test names and MACs to a file and point piHole.clients.file at it. Then:
#   1. wait for pihole-ftl and pihole-clients, and check the journal reports
#      the groups and clients as created, with no name or MAC in it;
#   2. read gravity.db ('pihole-FTL sqlite3 /var/lib/pihole/gravity.db') and
#      compare client, group and client_by_group with the file;
#   3. restart pihole-clients: everything unchanged, nothing written;
#   4. edit the file (rename one, move one group, one unknown group) and restart:
#      updates are applied, the unknown group fails the unit, extras survive;
#   5. restart pihole-ftl: pihole-clients re-runs by itself (Requires=) with the
#      regenerated CLI password;
#   6. check systemd-analyze security pihole-clients stays low.
{ config, lib, pkgs, ... }:

let
  cfg = config.piHole.clients;
  ftl = config.services.pihole-ftl;

  # The setup unit only exists while adlists are declared. When it does, wait
  # for its first gravity run so the clients land in the final gravity.db.
  setupUnit = lib.optional (lib.attrByPath [
    "systemd"
    "services"
    "pihole-ftl-setup"
    "enable"
  ] false config) "pihole-ftl-setup.service";

  dnsPort = toString (lib.attrByPath [ "dns" "port" ] 53 ftl.settings);

  groupsFile = pkgs.writeText "pihole-clients-groups.json" (builtins.toJSON cfg.groups);

  apply = pkgs.writeShellApplication {
    name = "pihole-clients-apply";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      dnsutils
      gnugrep
      jq
    ];
    text = ''
      # Output carries counts and list positions only: client names and MAC
      # addresses are private and must never reach the journal.
      umask 077

      clients_file="''${CREDENTIALS_DIRECTORY:?not started by systemd with LoadCredential}/clients.json"
      groups_file="${groupsFile}"
      cli_pw_file="${ftl.configDirectory}/cli_pw"
      dns_port="${dnsPort}"
      api_timeout="${toString cfg.apiTimeout}"

      tmp_work=""
      if [[ -n ''${RUNTIME_DIRECTORY:-} ]]; then
        work="$RUNTIME_DIRECTORY"
      else
        tmp_work="$(mktemp -d)"
        work="$tmp_work"
      fi
      body_file="$work/body"
      err_file="$work/curl-err"
      sid_file="$work/sid-header"
      groups_state="$work/groups.json"
      clients_state="$work/clients.json"

      api_url=""
      code=000
      last_error=""
      logged_in=false

      log() { echo "pihole-clients: $*"; }
      die() {
        echo "pihole-clients: error: $*" >&2
        exit 1
      }

      # call METHOD PATH [JSON]: the HTTP status goes to $code, the response
      # body to $body_file. The JSON and the session header reach curl through
      # a pipe and a file, so neither the password nor the session id is in argv.
      call() {
        local method="$1" path="$2" data="''${3-}" rc=0
        local -a args=(
          --silent --show-error --insecure --globoff
          --connect-timeout 3 --max-time 30
          --request "$method" --header 'Accept: application/json'
          --output "$body_file" --write-out '%{http_code}'
        )
        if [[ -s $sid_file ]]; then
          args+=(--header "@$sid_file")
        fi
        if [[ -n $data ]]; then
          args+=(--header 'Content-Type: application/json' --data-binary @-)
        fi
        : >"$body_file"
        code="$(printf '%s' "$data" | curl "''${args[@]}" "$api_url$path" 2>"$err_file")" || rc=$?
        if ((rc != 0)); then
          code=000
          last_error="curl exit $rc"
        fi
      }

      # The error key and message of the last response. The hint is left out
      # on purpose: FTL echoes the offending item in it.
      api_error() {
        jq -r '[.error.key // empty, .error.message // empty] | join(": ")' "$body_file" 2>/dev/null || true
      }

      uri() { jq -rn --arg v "$1" '$v | @uri'; }

      # FTL publishes its API URLs as a CHAOS TXT record, which is also how
      # the pihole CLI finds them. Prefer plain HTTP on the loopback address.
      discover_api() {
        local reply
        reply="$(dig +short +time=2 +tries=1 -p "$dns_port" chaos txt local.api.ftl @127.0.0.1 2>/dev/null)" || true
        api_url="$(grep -o 'http://[^"]*' <<<"$reply" | head -n 1)" || true
        if [[ -z $api_url ]]; then
          api_url="$(grep -o 'https://[^"]*' <<<"$reply" | head -n 1)" || true
        fi
        [[ -n $api_url ]]
      }

      login() {
        local payload sid
        call GET auth
        case $code in
          200)
            # No password configured: the API is open and needs no session.
            : >"$sid_file"
            return 0
            ;;
          401) ;;
          *)
            last_error="auth probe returned HTTP $code"
            return 1
            ;;
        esac
        if [[ ! -r $cli_pw_file ]]; then
          last_error="CLI password file is not readable (is webserver.api.cli_pw enabled?)"
          return 1
        fi
        payload="$(jq -Rsc '{password: rtrimstr("\n")}' "$cli_pw_file")"
        call POST auth "$payload"
        sid="$(jq -r 'select(.session.valid == true) | .session.sid // empty' "$body_file" 2>/dev/null)" || sid=""
        if [[ $code != 200 || -z $sid ]]; then
          last_error="login rejected (HTTP $code)"
          return 1
        fi
        printf 'sid: %s\n' "$sid" >"$sid_file"
      }

      # One readiness attempt: API published, session open, gravity.db usable.
      # The session is opened once and reused, since FTL has few session slots.
      ready() {
        discover_api || {
          last_error="FTL has not published its API URL yet"
          return 1
        }
        if [[ $logged_in != true ]]; then
          login || return 1
          logged_in=true
        fi
        call GET groups
        case $code in
          200) return 0 ;;
          401)
            logged_in=false
            : >"$sid_file"
            last_error="session rejected"
            ;;
          *) last_error="groups endpoint returned HTTP $code $(api_error)" ;;
        esac
        return 1
      }

      cleanup() {
        if [[ $logged_in == true && -s $sid_file ]]; then
          call DELETE auth || true
        fi
        if [[ -n $tmp_work ]]; then
          rm -rf "$tmp_work"
        fi
      }
      trap cleanup EXIT

      # A write that ended the way it should: the expected status and no
      # per-item error in the processed block.
      write_ok() {
        [[ $code == "$1" ]] && jq -e '(.processed.errors // []) | length == 0' "$body_file" >/dev/null 2>&1
      }

      # --- Validate the private client list before touching FTL --------------

      [[ -r $clients_file ]] || die "the clients credential is not readable"
      jq -e 'type == "array"' "$clients_file" >/dev/null 2>&1 || die "the clients file is not a JSON array"

      bad="$(jq -r '
        [ to_entries[]
          | select((.value | (type == "object"
              and (.name | type == "string")
              and (.mac | type == "string" and length > 0 and (test("\\s") | not))
              and (.group | type == "string" and length > 0))) | not)
          | .key + 1 ]
        | map(tostring) | join(", ")' "$clients_file")"
      [[ -z $bad ]] || die "entries not shaped like {name, mac, group} with a space-free mac (positions): $bad"

      dups="$(jq -r '
        [ to_entries | group_by(.value.mac | ascii_downcase)[]
          | select(length > 1) | .[1:][] | .key + 1 ]
        | map(tostring) | join(", ")' "$clients_file")"
      [[ -z $dups ]] || die "duplicate client addresses at positions: $dups"

      n_clients="$(jq length "$clients_file")"
      n_groups="$(jq length "$groups_file")"

      # --- Wait for the API ----------------------------------------------------

      deadline=$((SECONDS + api_timeout))
      until ready; do
        if ((SECONDS >= deadline)); then
          die "FTL API not ready after $api_timeout s (last problem: $last_error)"
        fi
        sleep 2
      done
      log "API ready"

      failed=0

      # --- Groups --------------------------------------------------------------

      cp "$body_file" "$groups_state"
      groups_created=0
      groups_updated=0
      while IFS= read -r row; do
        name="$(jq -r '.name' <<<"$row")"
        desc="$(jq -r '.description' <<<"$row")"
        existing="$(jq -c --arg n "$name" 'first(.groups[] | select(.name == $n)) // empty' "$groups_state")"
        if [[ -z $existing ]]; then
          call POST groups "$(jq -nc --arg n "$name" --arg c "$desc" '{name: $n, comment: $c, enabled: true}')"
          if write_ok 201; then
            groups_created=$((groups_created + 1))
          else
            failed=$((failed + 1))
            log "creating a group failed: HTTP $code $(api_error)"
          fi
        elif [[ "$(jq -r '.comment // ""' <<<"$existing")" != "$desc" ]]; then
          # Only the description is managed: keep the enabled flag as it is.
          call PUT "groups/$(uri "$name")" "$(jq -nc --arg c "$desc" --argjson e "$(jq '.enabled' <<<"$existing")" '{comment: $c, enabled: $e}')"
          if write_ok 200; then
            groups_updated=$((groups_updated + 1))
          else
            failed=$((failed + 1))
            log "updating a group failed: HTTP $code $(api_error)"
          fi
        fi
      done < <(jq -c '.[]' "$groups_file")
      log "groups: $n_groups declared, $groups_created created, $groups_updated updated"

      call GET groups
      [[ $code == 200 ]] || die "cannot re-read groups: HTTP $code $(api_error)"
      cp "$body_file" "$groups_state"

      # --- Clients -------------------------------------------------------------

      call GET clients
      [[ $code == 200 ]] || die "cannot read clients: HTTP $code $(api_error)"
      cp "$body_file" "$clients_state"

      # One line of JSON per file entry: what to do and the PUT body. Addresses
      # match case-insensitively (FTL itself does), and an existing client is
      # addressed by the spelling it is stored under.
      plan() {
        jq -c --slurpfile cur "$clients_state" --slurpfile grp "$groups_state" '
          to_entries[]
          | .key as $k | .value as $c
          | ($grp[0].groups | map(select(.name == $c.group)) | first) as $g
          | ($cur[0].clients | map(select((.client | ascii_downcase) == ($c.mac | ascii_downcase))) | first) as $e
          | {
              pos: ($k + 1),
              client: ($e.client // $c.mac),
              body: {comment: $c.name, groups: [$g.id]},
              action: (
                if $g == null then "unknown-group"
                elif $e == null then "create"
                elif (($e.comment // "") != $c.name) or (($e.groups | sort) != [$g.id]) then "update"
                else "unchanged" end
              )
            }' "$clients_file"
      }

      created=0
      updated=0
      unchanged=0
      while IFS= read -r row; do
        action="$(jq -r '.action' <<<"$row")"
        pos="$(jq -r '.pos' <<<"$row")"
        case $action in
          unchanged)
            unchanged=$((unchanged + 1))
            continue
            ;;
          unknown-group)
            failed=$((failed + 1))
            log "entry $pos: its group does not exist"
            continue
            ;;
          *) ;;
        esac
        call PUT "clients/$(uri "$(jq -r '.client' <<<"$row")")" "$(jq -c '.body' <<<"$row")"
        if write_ok 200; then
          if [[ $action == create ]]; then
            created=$((created + 1))
          else
            updated=$((updated + 1))
          fi
        else
          failed=$((failed + 1))
          log "entry $pos: $action failed: HTTP $code $(api_error)"
        fi
      done < <(plan)

      # Clients that are not in the file are never deleted, only counted.
      unmanaged="$(jq -r --slurpfile mine "$clients_file" '
        ($mine[0] | map(.mac | ascii_downcase)) as $macs
        | [ .clients[] | select((.client | ascii_downcase) | IN($macs[]) | not) ]
        | length' "$clients_state")"

      log "clients: $n_clients declared, $created created, $updated updated, $unchanged unchanged, $failed failed"
      log "clients not in the file, left untouched: $unmanaged"

      ((failed == 0)) || die "$failed change(s) failed, see above"
    '';
  };
in
{
  options.piHole.clients = {
    file = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/secrets/pihole-clients";
      description = ''
        Runtime path to a JSON array of Pi-hole clients, each an object
        `{ "name": str, "mac": str, "group": str }`. `mac` is the client
        identifier Pi-hole stores (a MAC address here, though an IP, hostname
        or interface works too), `name` becomes the client's comment and
        `group` names the single group it belongs to. Names and MACs are
        private, so point this at a secret (for example a sops-nix one), never
        at a file in the repo. The systemd manager reads the file as root, so it
        need not be readable by the pihole user. `null` disables the module.

        Clients and groups are only ever created or updated; anything not
        listed is left alone. `extract-clients.sh` (next to this module)
        builds the file from a Teleporter backup.
      '';
    };

    groups = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.strMatching "[^\r\n]+";
              description = "Group name, as referenced by the client file.";
            };
            description = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Group description. An existing group has it updated to this value.";
            };
          };
        }
      );
      default = [
        {
          name = "Obsolete";
          description = "Unused clients";
        }
      ];
      description = ''
        Groups that must exist before clients are assigned. The built-in
        `Default` group always exists and needs no entry. Which lists a group
        gets is not managed here.
      '';
    };

    apiTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 120;
      description = ''
        Seconds to wait for FTL's API (and a usable gravity.db) after the unit
        starts, before it fails.
      '';
    };
  };

  config = lib.mkIf (cfg.file != null) {
    assertions = [
      {
        assertion = ftl.enable && ftl.webserverEnabled;
        message = ''
          piHole.clients.file needs services.pihole-ftl.enable and its webserver
          (for example services.pihole-web.enable): the clients are applied
          through the FTL API.
        '';
      }
      {
        assertion = lib.attrByPath [ "webserver" "api" "cli_pw" ] true ftl.settings != false;
        message = ''
          piHole.clients.file needs services.pihole-ftl.settings.webserver.api.cli_pw
          to stay true: the unit authenticates with the CLI password.
        '';
      }
      {
        assertion = !(lib.any (g: g.name == "Default") cfg.groups);
        message = "piHole.clients.groups must not list the built-in Default group.";
      }
      {
        assertion = lib.length (lib.unique (map (g: g.name) cfg.groups)) == lib.length cfg.groups;
        message = "piHole.clients.groups has duplicate group names.";
      }
    ];

    systemd.services.pihole-clients = {
      description = "Declarative Pi-hole groups and clients";
      wantedBy = [ "multi-user.target" ];
      # Requires makes an explicit restart of FTL (a config change on switch)
      # re-run this unit too, which re-reads the regenerated CLI password. The
      # setup unit is only a soft dependency: a failed list download there
      # must not stop the clients from being applied.
      requires = [ "pihole-ftl.service" ];
      after = [ "pihole-ftl.service" ] ++ setupUnit;
      wants = setupUnit;

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.getExe apply;
        TimeoutStartSec = cfg.apiTimeout + 60;

        # /etc/pihole is 0700 pihole:pihole and cli_pw lives in it, so the
        # unit has to run as the FTL user. The client list comes in as a
        # credential, which the manager reads as root.
        User = ftl.user;
        Group = ftl.group;
        LoadCredential = "clients.json:${cfg.file}";
        RuntimeDirectory = "pihole-clients";
        RuntimeDirectoryMode = "0700";
        UMask = "0077";

        # Hardening: a loopback HTTP and DNS client with nothing to write.
        CapabilityBoundingSet = "";
        AmbientCapabilities = "";
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        PrivateUsers = true;
        DevicePolicy = "closed";
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectControlGroups = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectKernelLogs = true;
        ProtectClock = true;
        ProtectHostname = true;
        ProtectProc = "invisible";
        ProcSubset = "pid";
        RestrictAddressFamilies = "AF_UNIX AF_INET AF_INET6 AF_NETLINK";
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        MemoryDenyWriteExecute = true;
        LockPersonality = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
        ];
        IPAddressDeny = "any";
        IPAddressAllow = "localhost";
      };
    };
  };
}
