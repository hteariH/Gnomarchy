# Snapshots and Rollback

The root filesystem is Btrfs with Snapper, and snapshots appear in the Limine
boot menu. If an update breaks something, reboot and pick the previous
snapshot.

```bash
gnomarchy snapshot create "Before trying something risky"
gnomarchy snapshot list
```

Also under Snapshot in the command center.

## Automatic snapshots

`snap-pac` takes one before and after every pacman transaction, so a package
update that goes wrong is already covered without you doing anything.

## Rolling back

1. Reboot.
2. In the Limine menu, choose the snapshot from before the change.
3. You are booted into that state, read-write.

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
