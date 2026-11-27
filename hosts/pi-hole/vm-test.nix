# Runtime test of the pi-hole host's DNS stack in an x86_64 NixOS VM: FTL +
# unbound + the declarative clients unit, with fixture data. It cannot cover the
# Pi-specific parts (SD image, NIC name, Tailscale, sops) - those are checked on
# the device at cutover - but it is the only way to run the service wiring before
# the household's DNS depends on it. Run it on gaming:
#   nix build .#packages.x86_64-linux.pihole-vm-test -L
{ pkgs }:

let
  # Blocklist in hosts format, read through file:// so the VM needs no network.
  blocklist = pkgs.writeText "fixture-blocklist.txt" ''
    0.0.0.0 ads.fixture.org
  '';

  clients = pkgs.writeText "fixture-clients.json" (builtins.toJSON [
    { name = "Test Phone"; mac = "aa:bb:cc:dd:ee:01"; group = "Default"; }
    { name = "Test Old Laptop"; mac = "aa:bb:cc:dd:ee:02"; group = "Obsolete"; }
  ]);
in
pkgs.testers.runNixOSTest {
  name = "pihole-host";

  nodes.machine = { pkgs, ... }: {
    imports = [
      ./pihole.nix
      ./clients.nix
    ];

    # The real board has 1 GB.
    virtualisation.memorySize = 1024;

    # Same as hosts/pi-hole/configuration.nix: the box resolves through itself
    # first. Gravity (run by the setup unit) waits for local DNS before it builds
    # the blocklist, so without this it times out and gravity.db is never made.
    networking.nameservers = [ "127.0.0.1" ];

    services.pihole-ftl.lists = [
      {
        url = "file://${blocklist}";
        type = "block";
        description = "fixture blocklist";
      }
    ];

    # A password makes the API answer 401, so the unit's CLI-password login is
    # really exercised (FTL hashes it on start).
    piHole.webEnvFile = pkgs.writeText "pihole-web-env" "FTLCONF_webserver_api_password=fixture-password\n";
    piHole.clients.file = clients;

    # No internet in the VM: unbound answers this zone itself. ads.fixture.org
    # gets a decoy address, so a 0.0.0.0 answer can only come from FTL blocking it.
    services.unbound.settings.server = {
      # gravity also insists on resolving raw.githubusercontent.com and
      # github.com before it builds the list, so those get stub answers too.
      local-zone = [
        ''"fixture.org." static''
        ''"github.com." static''
        ''"githubusercontent.com." static''
      ];
      local-data = [
        ''"good.fixture.org. 60 IN A 192.0.2.10"''
        ''"ads.fixture.org. 60 IN A 192.0.2.66"''
        ''"github.com. 60 IN A 192.0.2.1"''
        ''"raw.githubusercontent.com. 60 IN A 192.0.2.1"''
      ];
    };

    environment.systemPackages = [ pkgs.dnsutils ];
  };

  testScript = { nodes, ... }: ''
    ftl = "${nodes.machine.services.pihole-ftl.package}/bin/pihole-FTL"

    def sql(q):
        machine.succeed("cat > /tmp/q.sql <<'EOF'\n{}\nEOF".format(q))
        return machine.succeed("{} sqlite3 -readonly /var/lib/pihole/gravity.db < /tmp/q.sql".format(ftl)).strip()

    def config(key):
        return machine.succeed("{} --config {}".format(ftl, key)).strip()

    start_all()
    machine.wait_for_unit("unbound.service")
    machine.wait_for_unit("pihole-ftl.service")
    machine.wait_for_unit("pihole-clients.service")

    with subtest("a normal name resolves through FTL and unbound"):
        # Diagnostics first: which hop answers, so a failure names the culprit.
        for cmd in [
            "dig @127.0.0.1 -p 5335 good.fixture.org +time=3 +tries=1",
            "dig @127.0.0.1 good.fixture.org +time=3 +tries=1",
            "journalctl -u unbound --no-pager | tail -15",
            "grep -E 'good.fixture.org|ads.fixture.org' /var/log/pihole/pihole.log | tail -12",
            "grep -iE 'upstream|dns_servers|server=|local=' /etc/pihole/dnsmasq.conf /var/lib/pihole/dnsmasq.conf 2>/dev/null | head",
            "tail -8 /var/log/pihole/FTL.log",
        ]:
            print("### " + cmd + "\n" + machine.execute(cmd)[1])
        machine.wait_until_succeeds("dig +short @127.0.0.1 good.fixture.org | grep -qx 192.0.2.10", timeout=30)

    with subtest("a listed name is blocked with the NULL address, not unbound's decoy"):
        machine.wait_until_succeeds("dig +short @127.0.0.1 ads.fixture.org | grep -qx 0.0.0.0", timeout=120)

    with subtest("live settings carried over"):
        assert "127.0.0.1#5335" in config("dns.upstreams"), config("dns.upstreams")
        assert config("dns.listeningMode") == "ALL", config("dns.listeningMode")
        assert config("dns.dnssec") == "false", config("dns.dnssec")
        assert config("ntp.sync.active") == "false", config("ntp.sync.active")
        assert config("ntp.ipv4.active") == "false", config("ntp.ipv4.active")

    with subtest("the web interface answers on port 80"):
        code = machine.succeed("curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1/").strip()
        assert code[0] in "23", code

    with subtest("groups and clients were created from the file"):
        assert sql("SELECT count(*) FROM client;") == "2"
        assert sql("SELECT count(*) FROM \"group\" WHERE name = 'Obsolete';") == "1"
        rows = sql(
            "SELECT c.comment || '|' || g.name FROM client c "
            "JOIN client_by_group cg ON cg.client_id = c.id "
            "JOIN \"group\" g ON g.id = cg.group_id ORDER BY c.comment;"
        )
        assert rows == "Test Old Laptop|Obsolete\nTest Phone|Default", rows

    with subtest("the journal holds no client name or MAC"):
        machine.fail("journalctl -u pihole-clients --no-pager | grep -E 'Test Phone|Test Old Laptop|aa:bb:cc'")

    with subtest("re-running the clients unit changes nothing"):
        machine.succeed("systemctl restart pihole-clients.service")
        assert sql("SELECT count(*) FROM client;") == "2"

    with subtest("restarting FTL re-applies the clients by itself"):
        machine.succeed("systemctl restart pihole-ftl.service")
        machine.wait_for_unit("pihole-clients.service")
        assert sql("SELECT count(*) FROM client;") == "2"

    with subtest("the weekly gravity timer exists and a manual run works"):
        machine.succeed("systemctl list-timers --all | grep -q pihole-gravity")
        machine.succeed("systemctl start pihole-gravity.service")
        machine.wait_until_succeeds("dig +short @127.0.0.1 ads.fixture.org | grep -qx 0.0.0.0", timeout=120)
  '';
}
