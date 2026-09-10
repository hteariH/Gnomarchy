#!/usr/bin/env bash

# Gnomarchy Automated Live ISO Installer
set -e

# Set terminal color theme (Tokyo Night)
echo -en "\e]P01a1b26\e]P1f7768e\e]P29ece6a\e]P3e0af68\e]P47aa2f7\e]P5bb9af7\e]P67dcfff\e]P7a9b1d6"
echo -en "\e]P8414868\e]P9f7768e\e]PA9ece6a\e]PBe0af68\e]PC7aa2f7\e]PDbb9af7\e]PE7dcfff\e]PFc0caf5"
echo -en "\033[0m"
clear

echo -e "\033[1;36m"
cat <<'EOF'
   ____  _   _   ___   __  __     _    ____    ____  _   _ __   __
  / ___|| \ | | / _ \ |  \/  |   / \  |  _ \  / ___|| | | |\ \ / /
 | |  _ |  \| || | | || |\/| |  / _ \ | |_) || |    | |_| | \ V / 
 | |_| || |\  || |_| || |  | | / ___ \|  _ < | |___ |  _  |  | |  
  \____||_| \_| \___/ |_|  |_|/_/   \_\|_| \_\ \____||_| |_|  |_|  
EOF
echo -e "\033[0m"
echo -e "\033[1;32mWelcome to the Gnomarchy Linux Installer!\033[0m\n"

# Detect firmware boot mode
if [ -d /sys/firmware/efi/efivars ]; then
  BOOT_MODE="UEFI"
else
  BOOT_MODE="Legacy BIOS"
fi

echo -e "Firmware Boot Mode: \033[1;35m$BOOT_MODE\033[0m"
if [ "$BOOT_MODE" = "Legacy BIOS" ]; then
  echo -e "\033[1;33m[NOTE]\033[0m Booted in Legacy BIOS mode. Gnomarchy will install with Universal BIOS + UEFI dual-boot support."
  echo -e "\033[0;36m       (Tip for VirtualBox: You can also enable native EFI in VM Settings -> System -> Motherboard -> [x] Enable EFI)\033[0m\n"
else
  echo -e "\033[1;32m[OK]\033[0m Booted in modern UEFI mode.\n"
fi

# Detect available hard disks (excluding read-only optical drives like sr0 and loop devices)
available_disks=($(lsblk -d -n -o NAME,TYPE | awk '$2=="disk"{print $1}'))
default_disk=""
if [ ${#available_disks[@]} -eq 1 ]; then
  default_disk="/dev/${available_disks[0]}"
fi

echo "Available Storage Disks:"
lsblk -d -n -o NAME,SIZE,MODEL,TYPE | grep -v "loop" | grep -v "airootfs"
echo ""

while true; do
  echo "Select disk to install Gnomarchy onto (WARNING: THIS DISK WILL BE WIPED):"
  prompt="Target disk (e.g. sda, /dev/sda, nvme0n1)"
  if [ -n "$default_disk" ]; then
    prompt="$prompt [default: $default_disk]"
  fi
  read -rp "$prompt: " input_disk
  input_disk="${input_disk:-$default_disk}"

  # Normalize input: handle /sda, sda, dev/sda, /dev/sda
  cleaned="${input_disk#/}"
  if [[ "$cleaned" =~ ^dev/ ]]; then
    TARGET_DISK="/$cleaned"
  elif [[ "$cleaned" =~ ^[a-zA-Z0-9]+ ]]; then
    TARGET_DISK="/dev/$cleaned"
  else
    TARGET_DISK="$input_disk"
  fi

  if [ -b "$TARGET_DISK" ]; then
    echo -e "✓ Selected target disk: \033[1;32m$TARGET_DISK\033[0m\n"
    break
  else
    echo -e "\033[1;31m[ERROR]\033[0m '$TARGET_DISK' is not a valid block device. Please choose from the list above.\n"
  fi
done

while true; do
  read -rp "Full Name: " USER_FULLNAME
  if [ -n "$USER_FULLNAME" ]; then break; fi
  echo "Full name cannot be empty."
done

while true; do
  read -rp "Username: " USERNAME
  USERNAME=$(echo "$USERNAME" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
  if [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; then break; fi
  echo "Invalid username. Must start with a letter and contain only lowercase letters, digits, or hyphens."
done

while true; do
  read -rsp "Password: " PASSWORD
  echo ""
  read -rsp "Confirm Password: " PASSWORD_CONFIRM
  echo ""
  if [[ -n "$PASSWORD" && "$PASSWORD" == "$PASSWORD_CONFIRM" ]]; then
    break
  fi
  echo -e "\033[1;31mPasswords do not match or empty. Please try again.\033[0m\n"
done

read -rp "Encrypt system with LUKS? (Y/n): " ENCRYPT_OPT
ENCRYPT_OPT="${ENCRYPT_OPT:-Y}"

echo -e "\n\033[1;33mPreparing installation on $TARGET_DISK...\033[0m"

# Unmount existing mounts
umount -R /mnt 2>/dev/null || true
swapoff -a 2>/dev/null || true

# Wipe disk partition table
wipefs -af "$TARGET_DISK"
sgdisk --zap-all "$TARGET_DISK"

# Create partitions:
# 1 = BIOS Boot Partition (1MB, ef02) for Legacy BIOS booting on GPT
# 2 = EFI System Partition (1024MB, ef00) for UEFI booting on GPT
# 3 = Linux Root (rest of disk, 8300)
sgdisk -n 1:0:+1M     -t 1:ef02 -c 1:"BIOS Boot Partition" "$TARGET_DISK"
sgdisk -n 2:0:+1024M  -t 2:ef00 -c 2:"EFI System Partition" "$TARGET_DISK"
sgdisk -n 3:0:0       -t 3:8300 -c 3:"Gnomarchy Root" "$TARGET_DISK"

# Partprobe
partprobe "$TARGET_DISK"
sleep 2

# Determine partition names
if [[ "$TARGET_DISK" =~ [0-9]$ ]]; then
  BIOS_PART="${TARGET_DISK}p1"
  EFI_PART="${TARGET_DISK}p2"
  ROOT_PART="${TARGET_DISK}p3"
else
  BIOS_PART="${TARGET_DISK}1"
  EFI_PART="${TARGET_DISK}2"
  ROOT_PART="${TARGET_DISK}3"
fi

# Format EFI
mkfs.vfat -F32 -n "BOOT" "$EFI_PART"

# LUKS Setup
FS_DEV="$ROOT_PART"
if [[ "$ENCRYPT_OPT" =~ ^[Yy]$ ]]; then
  echo "Configuring LUKS disk encryption..."
  echo -n "$PASSWORD" | cryptsetup luksFormat --type luks2 --pbkdf argon2id "$ROOT_PART" -
  echo -n "$PASSWORD" | cryptsetup open "$ROOT_PART" cryptroot -
  FS_DEV="/dev/mapper/cryptroot"
fi

# Format Btrfs
echo "Formatting Btrfs filesystem and subvolumes..."
mkfs.btrfs -f -L "GNOMARCHY" "$FS_DEV"
mount "$FS_DEV" /mnt

# Subvolumes
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@var_cache
umount /mnt

# Mount subvolumes
BTRFS_OPTS="noatime,compress=zstd:2,space_cache=v2,discard=async"
mount -o "$BTRFS_OPTS,subvol=@" "$FS_DEV" /mnt
mkdir -p /mnt/{boot,home,.snapshots,var/log,var/cache}
mount -o "$BTRFS_OPTS,subvol=@home" "$FS_DEV" /mnt/home
mount -o "$BTRFS_OPTS,subvol=@snapshots" "$FS_DEV" /mnt/.snapshots
mount -o "$BTRFS_OPTS,subvol=@var_log" "$FS_DEV" /mnt/var/log
mount -o "$BTRFS_OPTS,subvol=@var_cache" "$FS_DEV" /mnt/var/cache
mount "$EFI_PART" /mnt/boot

# Install base system via pacstrap
echo "Installing base Arch Linux system packages..."
pacstrap -K /mnt base base-devel linux linux-firmware btrfs-progs sudo git curl neovim networkmanager limine

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Setup crypttab if encrypted
if [[ "$ENCRYPT_OPT" =~ ^[Yy]$ ]]; then
  ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")
  echo "cryptroot UUID=$ROOT_UUID none luks,discard" >> /mnt/etc/crypttab
  
  # Add encrypt hook to mkinitcpio
  sed -i 's/HOOKS=(\(.*\)block\(.*\)filesystems\(.*\))/HOOKS=(\1block encrypt\2filesystems\3)/' /mnt/etc/mkinitcpio.conf
fi

# Chroot base system setup
arch-chroot /mnt /bin/bash <<CHROOT_EOF
set -e

# Timezone & Locale
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "gnomarchy-linux" > /etc/hostname

# Sudoers
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/10-wheel

# Create User
useradd -m -G wheel -s /bin/bash "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd
echo "root:$PASSWORD" | chpasswd

# Initramfs
mkinitcpio -P

# Limine bootloader setup (Universal Dual-Boot BIOS + UEFI)
echo "Installing Limine bootloader (BIOS + UEFI)..."
cp /usr/share/limine/limine-bios.sys /boot/ 2>/dev/null || true
limine bios-install "$TARGET_DISK" 2>/dev/null || true
mkdir -p /boot/EFI/BOOT
cp /usr/share/limine/BOOTX64.EFI /boot/EFI/BOOT/ 2>/dev/null || true
cp /usr/share/limine/BOOTIA32.EFI /boot/EFI/BOOT/ 2>/dev/null || true
if [ -d /sys/firmware/efi/efivars ]; then
  efibootmgr --create --disk "$TARGET_DISK" --part 2 --loader '/EFI/BOOT/BOOTX64.EFI' --label 'Gnomarchy' 2>/dev/null || true
fi

# Limine config
cat <<LIMINE_EOF > /boot/limine.conf
timeout: 3

/Gnomarchy Linux
    protocol: linux
    kernel_path: boot():/vmlinuz-linux
    kernel_cmdline: root=UUID=$(blkid -s UUID -o value "$FS_DEV") rw rootflags=subvol=@ quiet splash
    module_path: boot():/initramfs-linux.img
LIMINE_EOF

# Enable NetworkManager
systemctl enable NetworkManager.service
CHROOT_EOF

# Copy Gnomarchy repo into user home
echo "Deploying Gnomarchy to user home..."
mkdir -p "/mnt/home/$USERNAME/.local/share/gnomarchy"
if [ -d /root/gnomarchy ]; then
  cp -r /root/gnomarchy/* "/mnt/home/$USERNAME/.local/share/gnomarchy/"
else
  git clone https://github.com/hteariH/Gnomarchy.git "/mnt/home/$USERNAME/.local/share/gnomarchy"
fi

chmod +x "/mnt/home/$USERNAME/.local/share/gnomarchy/bin"/* 2>/dev/null || true
ln -sf "/home/$USERNAME/.local/share/gnomarchy/bin/gnomarchy" /mnt/usr/local/bin/gnomarchy 2>/dev/null || true
chown -R 1000:1000 "/mnt/home/$USERNAME/.local"

# Run Gnomarchy desktop installer inside chroot
echo -e "\n\033[1;36m==> Executing Gnomarchy Desktop & Environment Installer\033[0m"
arch-chroot -u "$USERNAME" /mnt /bin/bash -c "
  export GNOMARCHY_PATH=\"/home/$USERNAME/.local/share/gnomarchy\"
  export GNOMARCHY_CHROOT_INSTALL=1
  export USER=\"$USERNAME\"
  export HOME=\"/home/$USERNAME\"
  export PATH=\"/usr/local/bin:/home/$USERNAME/.local/share/gnomarchy/bin:\$PATH\"
  bash /home/$USERNAME/.local/share/gnomarchy/install.sh
"
chmod +x "/mnt/home/$USERNAME/.local/share/gnomarchy/bin"/* 2>/dev/null || true
ln -sf "/home/$USERNAME/.local/share/gnomarchy/bin/gnomarchy" /mnt/usr/local/bin/gnomarchy 2>/dev/null || true

# Preinstall Flatpak applications directly into target system storage
echo -e "\n\033[1;36m==> Preinstalling Flatpak Desktop Applications (Bazaar App Store, LocalSend)\033[0m"
if command -v flatpak >/dev/null 2>&1; then
  mkdir -p /etc/flatpak/installations.d /mnt/var/lib/flatpak
  cat <<'TARGET_FLATPAK_EOF' > /etc/flatpak/installations.d/target.conf
[Installation "target"]
Path=/mnt/var/lib/flatpak
DisplayName=Target System
StorageType=harddisk
TARGET_FLATPAK_EOF

  flatpak remote-add --if-not-exists --installation=target flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
  flatpak install -y --noninteractive --installation=target flathub io.github.kolunmi.Bazaar org.localsend.localsend_app 2>/dev/null || true
  rm -f /etc/flatpak/installations.d/target.conf

  # Configure flathub remote inside target system
  arch-chroot /mnt flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
fi

echo -e "\n\033[1;32mInstallation complete! Unmounting filesystems...\033[0m"
umount -R /mnt
if [[ "$ENCRYPT_OPT" =~ ^[Yy]$ ]]; then
  cryptsetup close cryptroot 2>/dev/null || true
fi

echo -e "\nRebooting into your new Gnomarchy installation in 5 seconds (or press Enter)..."
read -t 5 -r || true
reboot
