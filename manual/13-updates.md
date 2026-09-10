# Updates

```bash
gnomarchy update
```

This does four things: updates Arch packages, updates AUR packages, pulls the
Gnomarchy configuration, and applies any migrations that came with it.

It reports which stages failed and exits non-zero if any did. A green tick
means all four actually succeeded.

## Migrations

Editing a file in the Gnomarchy repository only affects new installs. Machines
that are already running need a migration - a timestamped script, applied
exactly once, recorded in:

    ~/.local/state/gnomarchy/migrations.log

```bash
gnomarchy migrate --list
gnomarchy migrate
```

`gnomarchy update` runs pending migrations automatically after the pull. This
is how configuration changes reach a machine that was installed months ago.

## Writing one

Add `migrations/<YYYY-MM-DD-HHMM>-<slug>.sh`. It must be idempotent: it may run
on a machine in any prior state, and re-running must not double-apply.

## If the pull fails

The Gnomarchy checkout is deployed, not authored. If you have local changes
they are stashed automatically and the command tells you how to get them back:

```bash
git -C ~/.local/share/gnomarchy stash pop
```

## Rolling back an update

See `gnomarchy manual 14`.
