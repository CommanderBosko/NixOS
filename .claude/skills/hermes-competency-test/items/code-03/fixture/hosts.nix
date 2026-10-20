# Render an /etc/hosts fragment from an attrset of hosts.
#
# Call it as:
#
#   import ./hosts.nix {
#     hosts = {
#       nas    = { ip = "192.0.2.10"; aliases = [ "files" "backup" ]; };
#       laptop = { ip = "192.0.2.9"; };
#       old-pc = { ip = "192.0.2.77"; enable = false; };
#     };
#     domain = "home.arpa";
#   }
#
# Arguments
#   hosts   An attrset. Each attribute name is the host's short name; each value is an
#           attrset with exactly these attributes (no others):
#             ip       string, required: a dotted-quad IPv4 address
#             aliases  list of strings, optional (default [])
#             enable   bool, optional (default true); disabled hosts are left out entirely
#   domain  A string, or null (optional, default null).
#
# Result: one string containing one line per enabled host, each line ending in "\n".
#   Fields are separated by single spaces:
#       <ip> <name>.<domain> <name> <alias1> <alias2> ...
#   When domain is null the "<name>.<domain>" field is left out:
#       <ip> <name> <alias1> <alias2> ...
#   Aliases keep the order they were given in.
#   Lines are sorted by IP address in numeric order, comparing octet by octet, so 192.0.2.9 comes
#   before 192.0.2.10 and 100.64.0.1 before 192.0.2.1.
#   With no enabled hosts the result is "" (the empty string).
#   For the example call above:
#       "192.0.2.9 laptop.home.arpa laptop\n192.0.2.10 nas.home.arpa nas files backup\n"
#
# Validation. Each of these must make evaluation fail through `throw` (so that
# `builtins.tryEval` can catch it, unlike `abort` or a type error), with a message that names the
# offending host:
#   - ip is not exactly four dot-separated decimal octets, each 0-255, written without leading
#     zeros ("0" on its own is fine; "07" is not)
#   - the host name or one of its aliases is not a valid label: 1-63 characters from a-z, 0-9 and
#     "-", not starting or ending with "-" (uppercase is not allowed)
#   - two enabled hosts have the same ip
#   - a host's attrset has an attribute other than ip, aliases and enable, or has no ip
# Disabled hosts are not validated at all.
#
# Use Nix builtins only: no nixpkgs, no lib, no imports.
{ hosts, domain ? null }:

throw "hosts.nix: not implemented yet"
