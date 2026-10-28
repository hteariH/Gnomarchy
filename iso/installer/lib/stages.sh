#!/bin/bash
# The seven installation stages. Each runs in its own subshell with
# `set -Eeuo pipefail`, its output in the installer log, so a stage must not
# set anything a later stage reads; disk_layout computes all of that up front.

STAGE_FNS=(stage_partition stage_filesystems stage_base stage_configure
  stage_bootloader stage_desktop stage_finish)
STAGE_TITLES=("Partition disk" "Create filesystems" "Install base system"
  "Configure system" "Install bootloader" "Install Gnomarchy desktop"
  "First snapshot and cleanup")

BTRFS_OPTS="noatime,compress=zstd:2,space_cache=v2,discard=async"

stage_partition() {
  # Whatever an earlier attempt left holding the target.
  if mountpoint -q /mnt; then umount -R /mnt; fi
  if [[ -e /dev/mapper/cryptroot ]]; then cryptsetup close cryptroot; fi
  swapoff -a
  wipefs -af "$DISK"
  sgdisk --zap-all "$DISK"
  sgdisk -n 1:0:+1M -t 1:ef02 -c 1:"BIOS boot" "$DISK"
  sgdisk -n 2:0:+4G -t 2:ef00 -c 2:"EFI system" "$DISK"
  sgdisk -n 3:0:0 -t 3:8300 -c 3:"Gnomarchy root" "$DISK"
  partprobe "$DISK"
  udevadm settle
  [[ -b "$ROOT_PART" ]] || { echo "partition $ROOT_PART did not appear"; return 1; }
}

stage_filesystems() {
  local sub
  mkfs.vfat -F32 -n BOOT "$ESP_PART"
  if [[ "$ENCRYPT" == y ]]; then
    # --key-file=- takes stdin verbatim, so no trailing newline joins the key.
    printf '%s' "$DISK_PASSWORD" |
      cryptsetup luksFormat --batch-mode --type luks2 --pbkdf argon2id --key-file=- "$ROOT_PART"
    printf '%s' "$DISK_PASSWORD" | cryptsetup open --key-file=- "$ROOT_PART" cryptroot
  fi
  mkfs.btrfs -f -L GNOMARCHY "$FS_DEV"
  mount "$FS_DEV" /mnt
  for sub in @ @home @snapshots @var_log @var_cache; do
    btrfs subvolume create "/mnt/$sub"
  done
  umount /mnt
  mount -o "$BTRFS_OPTS,subvol=@" "$FS_DEV" /mnt
  mkdir -p /mnt/{boot,home,.snapshots,var/log,var/cache}
  mount -o "$BTRFS_OPTS,subvol=@home" "$FS_DEV" /mnt/home
  mount -o "$BTRFS_OPTS,subvol=@snapshots" "$FS_DEV" /mnt/.snapshots
  mount -o "$BTRFS_OPTS,subvol=@var_log" "$FS_DEV" /mnt/var/log
  mount -o "$BTRFS_OPTS,subvol=@var_cache" "$FS_DEV" /mnt/var/cache
  mount "$ESP_PART" /mnt/boot
}

stage_base() {
  # efibootmgr for the bootloader stage; plymouth because the initramfs HOOKS
  # name it before install.sh would have installed it.
  pacstrap -K /mnt base base-devel linux linux-firmware btrfs-progs sudo git curl \
    neovim networkmanager limine efibootmgr plymouth
  genfstab -U /mnt >>/mnt/etc/fstab
  # Mount by subvolume name only: a subvolid pins / to @, so neither a snapshot
  # nor a restored @ would mount.
  sed -i -E -e 's/,subvolid=[0-9]+//' -e 's/subvolid=[0-9]+,//' /mnt/etc/fstab
  if grep -q 'subvolid=' /mnt/etc/fstab; then
    echo "fstab still pins a subvolid"
    return 1
  fi
}

stage_configure() {
  local repo="/mnt/home/$USERNAME/.local/share/gnomarchy" cmd fs_uuid luks_uuid cmdline encrypted=0

  ln -sf "/usr/share/zoneinfo/$TIMEZONE" /mnt/etc/localtime
  arch-chroot /mnt hwclock --systohc
  echo "en_US.UTF-8 UTF-8" >>/mnt/etc/locale.gen
  arch-chroot /mnt locale-gen
  echo "LANG=en_US.UTF-8" >/mnt/etc/locale.conf
  echo "$TARGET_HOSTNAME" >/mnt/etc/hostname
  cat >/mnt/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $TARGET_HOSTNAME.localdomain $TARGET_HOSTNAME
EOF

  # Keyboard: console and initramfs (a LUKS passphrase is typed here), X11 and
  # GDM, and the record gnomarchy-first-run turns into GNOME input sources.
  {
    echo "KEYMAP=$KB_CONSOLE_KEYMAP"
    if [[ -n "$KB_CONSOLE_FONT" ]]; then echo "FONT=$KB_CONSOLE_FONT"; fi
  } >/mnt/etc/vconsole.conf
  mkdir -p /mnt/etc/X11/xorg.conf.d /mnt/etc/gnomarchy
  {
    echo 'Section "InputClass"'
    echo '    Identifier "system-keyboard"'
    echo '    MatchIsKeyboard "on"'
    echo "    Option \"XkbLayout\" \"$KB_XKB_LAYOUT\""
    if [[ -n "$KB_XKB_VARIANT" ]]; then echo "    Option \"XkbVariant\" \"$KB_XKB_VARIANT\""; fi
    echo 'EndSection'
  } >/mnt/etc/X11/xorg.conf.d/00-keyboard.conf
  printf 'XKB_LAYOUT=%s\nXKB_VARIANT=%s\nLATIN=%s\n' "$KB_XKB_LAYOUT" "$KB_XKB_VARIANT" "$KB_LATIN" \
    >/mnt/etc/gnomarchy/keyboard.conf

  echo "%wheel ALL=(ALL:ALL) ALL" >/mnt/etc/sudoers.d/10-wheel
  arch-chroot /mnt useradd -m -G wheel -s /bin/bash -c "$FULLNAME" "$USERNAME"
  printf '%s:%s\n' "$USERNAME" "$PASSWORD" | arch-chroot /mnt chpasswd
  printf 'root:%s\n' "$PASSWORD" | arch-chroot /mnt chpasswd
  arch-chroot /mnt systemctl enable NetworkManager.service

  # The repository, now rather than after the chroot step: the boot tooling
  # below is deployed from it.
  mkdir -p "$repo"
  cp -a /root/gnomarchy/. "$repo/"
  chmod +x "$repo"/bin/*
  mkdir -p /mnt/usr/local/bin
  for cmd in "$repo"/bin/gnomarchy*; do
    ln -sf "/home/$USERNAME/.local/share/gnomarchy/bin/${cmd##*/}" "/mnt/usr/local/bin/${cmd##*/}"
  done
  arch-chroot /mnt chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.local"

  # Boot configuration. The root is opened from the command line, so there is
  # no crypttab entry for it.
  fs_uuid="$(blkid -s UUID -o value "$FS_DEV")"
  cmdline="root=UUID=$fs_uuid rw rootflags=subvol=@ quiet splash"
  if [[ "$ENCRYPT" == y ]]; then
    luks_uuid="$(blkid -s UUID -o value "$ROOT_PART")"
    cmdline="rd.luks.name=$luks_uuid=cryptroot rd.luks.options=discard $cmdline"
    encrypted=1
  fi
  mkdir -p /mnt/etc/kernel
  printf '%s\n' "$cmdline" >/mnt/etc/kernel/cmdline
  printf 'DISK=%s\nESP_PART=2\nENCRYPTED=%s\n' "$DISK" "$encrypted" >/mnt/etc/gnomarchy/boot.conf

  arch-chroot /mnt bash "/home/$USERNAME/.local/share/gnomarchy/default/boot/deploy.sh"
  arch-chroot /mnt mkinitcpio -P
}

stage_bootloader() {
  arch-chroot /mnt /usr/local/lib/gnomarchy/boot/gnomarchy-boot install
  arch-chroot /mnt /usr/local/lib/gnomarchy/boot/gnomarchy-boot update
}

stage_desktop() {
  local repo="/mnt/home/$USERNAME/.local/share/gnomarchy" theme_dir theme_name bg cmd

  # Bundled fallback wallpapers, one directory per theme:
  # gnomarchy-theme-set resolves /usr/share/backgrounds/gnomarchy/<theme>/.
  mkdir -p /mnt/usr/share/backgrounds/gnomarchy
  for theme_dir in "$repo"/themes/*/; do
    theme_name="$(basename "$theme_dir")"
    for bg in "$theme_dir"backgrounds/*; do
      [[ -f "$bg" ]] || continue
      install -Dm644 "$bg" "/mnt/usr/share/backgrounds/gnomarchy/$theme_name/${bg##*/}"
    done
  done

  # Flatpaks into the target's storage. Optional apps: report and go on.
  if command -v flatpak >/dev/null; then
    mkdir -p /etc/flatpak/installations.d /mnt/var/lib/flatpak
    printf '[Installation "target"]\nPath=/mnt/var/lib/flatpak\nDisplayName=Target System\nStorageType=harddisk\n' \
      >/etc/flatpak/installations.d/target.conf
    if flatpak remote-add --if-not-exists --installation=target flathub https://dl.flathub.org/repo/flathub.flatpakrepo &&
      flatpak install -y --noninteractive --installation=target flathub io.github.kolunmi.Bazaar org.localsend.localsend_app; then
      echo "Flatpaks preinstalled."
    else
      echo "warning: Flatpak preinstall failed; Bazaar and LocalSend can be installed later from Flathub."
    fi
    rm -f /etc/flatpak/installations.d/target.conf
    arch-chroot /mnt flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo ||
      echo "warning: could not add Flathub on the target."
  fi

  # Passwordless sudo for install.sh, which calls sudo throughout with nobody
  # watching. Removed when this stage's subshell exits, failure included.
  echo "$USERNAME ALL=(ALL:ALL) NOPASSWD: ALL" >/mnt/etc/sudoers.d/99-gnomarchy-install
  chmod 440 /mnt/etc/sudoers.d/99-gnomarchy-install
  trap 'rm -f /mnt/etc/sudoers.d/99-gnomarchy-install' EXIT

  arch-chroot -u "$USERNAME" /mnt /bin/bash -c "
    export GNOMARCHY_PATH=\"/home/$USERNAME/.local/share/gnomarchy\"
    export GNOMARCHY_CHROOT_INSTALL=1
    export USER=\"$USERNAME\"
    export HOME=\"/home/$USERNAME\"
    export PATH=\"/usr/local/bin:/home/$USERNAME/.local/share/gnomarchy/bin:\$PATH\"
    bash /home/$USERNAME/.local/share/gnomarchy/install.sh
  "

  # install.sh may have added commands; publish them all.
  for cmd in "$repo"/bin/gnomarchy*; do
    ln -sf "/home/$USERNAME/.local/share/gnomarchy/bin/${cmd##*/}" "/mnt/usr/local/bin/${cmd##*/}"
  done
}

stage_finish() {
  # Last on purpose: snap-pac (installed by install.sh) does nothing until the
  # root config exists, so the installation's transactions left no snapshots.
  arch-chroot /mnt /usr/local/lib/gnomarchy/boot/gnomarchy-boot snapper-init
}
