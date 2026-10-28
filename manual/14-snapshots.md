# Snapshots and Rollback

The root filesystem is Btrfs with Snapper, and every snapshot appears in the
Limine boot menu under **Gnomarchy → Snapshots**.

```bash
gnomarchy snapshot create "Before trying something risky"
gnomarchy snapshot list
gnomarchy snapshot restore 12
```

## Automatic snapshots

`snap-pac` takes one before and one after every pacman transaction, so a
package update that goes wrong is already covered. There are no timeline
snapshots. Snapper prunes only the pairs `snap-pac` takes, keeping the last
10 (5 marked important). Snapshots from `gnomarchy snapshot create` and
snapshot 1, "Gnomarchy installed", are kept until you delete them.

## Trying a snapshot

1. Reboot and open **Snapshots** in the Limine menu. Entries read
   `number | date time | description`, in plain ASCII.
2. Pick one. Each entry boots the kernel that snapshot was taken with.
3. The system starts from the snapshot, read-only underneath and writable in
   memory: anything you change is gone at the next reboot. A notification says
   so and offers to restore it.

## Restoring

`gnomarchy snapshot restore <number>` makes a snapshot the system from the
next boot on. It works from the normal system and from a snapshot you booted.
The system you had is kept as `@restore-backup-<time>` until the next restore.
Until you reboot, a second restore is refused.

## Limits

- Snapshot kernels live on the 4 GiB EFI partition. When it is more than 80%
  full the oldest snapshots leave the menu; they stay on disk and can still be
  restored.
- A snapshot taken under a kernel that is no longer on the EFI partition has
  no menu entry.

## Subvolume layout

    @            root
    @home        home, deliberately not rolled back with the system
    @snapshots   the snapshots themselves
    @var_log     logs, kept across rollbacks
    @var_cache   package cache

`@home` being separate is the important part: rolling the system back does not
take your documents with it.

## Before risky work

Ask an AI agent to snapshot first, or do it yourself. It costs nothing - Btrfs
snapshots are copy-on-write and take no space until things diverge.
