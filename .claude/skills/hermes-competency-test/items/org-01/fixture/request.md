# saturday job: paperless → new disk (brain dump, sorry)

ok so the SSD in nimbus (the little home server) is at 94% and most of that is paperless. I bought a
4 TB disk and it's physically installed. it's already formatted ext4 with the label `vault` but it is
NOT mounted and NOT in the nixos config yet. I want it mounted at /mnt/vault and paperless's data to
live at /mnt/vault/paperless.

- obviously at the very end I want the old /var/lib/paperless gone so the SSD has room again
- paperless config is in hosts/nimbus/paperless.nix, it's the `services.paperless.dataDir` option
- the mount should go in hosts/nimbus/hardware-configuration.nix like the other disks (by label)
- I rebuild with `nh os switch` on nimbus
- last time I moved something (the jellyfin metadata) I copied it while the service was running and
  the sqlite db came out corrupted. do NOT repeat that. paperless uses sqlite too
- before I delete anything I want to actually check it works: open a few documents in the web UI,
  and the document count in the UI should match what it was before (it's 4,812 right now)
- backup first!! to the usb drive (it mounts at /mnt/usb-backup), I don't trust myself
- the paperless units are paperless-web, paperless-consumer, paperless-scheduler and
  paperless-task-queue. I think the consume folder is inside the data dir as well
- the new directory has to be owned by the paperless user or it won't start
- oh and if the disk isn't mounted when nimbus boots, paperless should NOT start writing into an empty
  /mnt/vault on the SSD. no idea how you handle that in nixos
- nobody uses it saturday morning so downtime is fine, but I'd like it back up by lunch
