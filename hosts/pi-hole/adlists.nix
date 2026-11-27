# Blocklists declared into gravity.db by services.pihole-ftl.lists (see
# pihole.nix). Taken from the gravity.db of the Raspberry Pi OS install this host
# replaces, enabled lists only, so the new box blocks the same domains. Every list
# is a deny list; the description keeps the comment the old install carried (the
# "pihole-updatelists" ones were written by a tool that no longer runs here).
#
# The NixOS module only ever ADDS lists: a URL already in gravity.db is skipped,
# and deleting an entry here does NOT remove it from the database (remove it
# through the admin UI or API, or delete gravity.db and let the next start
# rebuild it).
#
# Deliberately not declared:
#   - URLhaus hostfile (urlhaus.abuse.ch/downloads/hostfile/): enabled on the old
#     install but dead. The endpoint now answers HTTP 410 and the list
#     contributed 0 domains.
#   - FadeMind hosts.extras add.Risk, Mandiant APT1 report appendix D (bitbucket
#     ethanr/dns-blacklists), and Firebog RPiList-Malware: disabled on the old
#     install, left out on purpose rather than carried over as dead rows.
[
  { url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"; description = "Migrated from /etc/pihole/adlists.list"; }
  { url = "https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADhosts.txt"; description = "Managed by pihole-updatelists"; }
  { url = "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Spam/hosts"; description = "Managed by pihole-updatelists"; }
  { url = "https://v.firebog.net/hosts/static/w3kbl.txt"; description = "Managed by pihole-updatelists"; }
  { url = "https://adaway.org/hosts.txt"; description = "Managed by pihole-updatelists"; }
  { url = "https://v.firebog.net/hosts/AdguardDNS.txt"; description = "Managed by pihole-updatelists"; }
  { url = "https://v.firebog.net/hosts/Admiral.txt"; description = "Managed by pihole-updatelists"; }
  { url = "https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt"; description = "Managed by pihole-updatelists"; }
  { url = "https://v.firebog.net/hosts/Easylist.txt"; description = "Managed by pihole-updatelists"; }
  { url = "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext"; description = "Managed by pihole-updatelists"; }
  { url = "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/UncheckyAds/hosts"; description = "Managed by pihole-updatelists"; }
  { url = "https://raw.githubusercontent.com/bigdargon/hostsVN/master/hosts"; description = "Managed by pihole-updatelists"; }
  { url = "https://v.firebog.net/hosts/Easyprivacy.txt"; description = "Managed by pihole-updatelists"; }
  { url = "https://v.firebog.net/hosts/Prigent-Ads.txt"; description = "Managed by pihole-updatelists"; }
  { url = "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.2o7Net/hosts"; description = "Managed by pihole-updatelists"; }
  { url = "https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt"; description = "Managed by pihole-updatelists"; }
  { url = "https://hostfiles.frogeye.fr/firstparty-trackers-hosts.txt"; description = "Managed by pihole-updatelists"; }
  { url = "https://v.firebog.net/hosts/Prigent-Crypto.txt"; description = "Managed by pihole-updatelists"; }
  { url = "https://phishing.army/download/phishing_army_blocklist_extended.txt"; description = "Managed by pihole-updatelists"; }
  { url = "https://gitlab.com/quidsup/notrack-blocklists/raw/master/notrack-malware.txt"; description = "Managed by pihole-updatelists"; }
  { url = "https://raw.githubusercontent.com/Spam404/lists/master/main-blacklist.txt"; description = "Managed by pihole-updatelists"; }
  { url = "https://raw.githubusercontent.com/AssoEchap/stalkerware-indicators/master/generated/hosts"; description = "Managed by pihole-updatelists"; }
  { url = "https://lists.cyberhost.uk/malware.txt"; description = "Managed by pihole-updatelists"; }
  { url = "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/tif.txt"; description = "HaGeZi Threat Intelligence Feed - malware/C2/phishing, added via /research 2026-08-25"; }
  { url = "https://raw.githubusercontent.com/DandelionSprout/adfilt/master/Alternate%20versions%20Anti-Malware%20List/AntiMalwareHosts.txt"; description = "DandelionSprout AntiMalwareHosts - malware/PUP/phishing, added via /research 2026-08-25"; }
]
