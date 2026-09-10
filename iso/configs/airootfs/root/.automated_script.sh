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
   ▄████████ █▄       ▄█     ▄████████  ▄▄▄▄███▄▄▄▄      ▄████████     ███        ▄██   ▄      
  ███    ███ ███     ███    ███    ███▄██▀▀▀███▀▀▀██▄   ███    ███ ▀█████████▄   ███   ██▄    
  ███    █▀  ███     ███    ███    ██████   ███   ███   ███    ███    ▀███▀▀██   ███▄▄▄███    
 ▄███        ███     ███    ███    ██████   ███   ███   ███    ███     ███   ▀   ▀▀▀▀▀▀███    
▀▀███ ████▄  ███     ███  ▀██████████████   ███   ███ ▀███████████     ███       ▄██   ███    
  ███    ███ ███     ███    ███    ██████   ███   ███   ███    ███     ███       ███   ███    
  ███    ███ ███ ▄█▄ ███    ███    ██████   ███   ███   ███    ███     ███       ███   ███    
  ████████▀   ▀███▀███▀     ███    █▀  ▀█   ███   █▀    ███    █▀     ▄████▀      ▀█████▀     
EOF
echo -e "\033[0m"
echo -e "\033[1;32mWelcome to the Gnomarchy Linux Installer!\033[0m\n"

# Verify UEFI boot
if [ ! -d /sys/firmware/efi/efivars ]; then
  echo -e "\033[1;31m[ERROR]\033[0m Gnomarchy requires booting in UEFI mode."
  exit 1
fi

# List disks
echo "Available Disks:"
lsblk -d -n -o NAME,SIZE,MODEL | grep -v "loop" | grep -v "airootfs"

echo -e "\nSelect disk to install Gnomarchy onto (WARNING: THIS DISK WILL BE WIPED):"
read -rp "Target disk (e.g. /dev/vda or /dev/nvme0n1): " TARGET_DISK

if [ ! -b "$TARGET_DISK" ]; then
  echo "Invalid block device: $TARGET_DISK"
  exit 1
fi

read -rp "Full Name: " USER_FULLNAME
read -rp "Username: " USERNAME
read -rsp "Password: " PASSWORD
echo ""
read -rsp "Confirm Password: " PASSWORD_CONFIRM
echo ""

if [[ "$PASSWORD" != "$PASSWORD_CONFIRM" ]]; then
  echo "Passwords do not match!"
  exit 1
fi

read -rp "Encrypt system with LUKS? (Y/n): " ENCRYPT_OPT
ENCRYPT_OPT="${ENCRYPT_OPT:-Y}"

echo -e "\n\033[1;33mPreparing installation on $TARGET_DISK...\033[0m"

# Unmount existing mounts
umount -R /mnt 2>/dev/null || true
swapoff -a 2>/dev/null || true

# Wipe disk partition table
wipefs -af "$TARGET_DISK"
sgdisk --zap-all "$TARGET_DISK"

# Create partitions: 1 = EFI (1G), 2 = Linux Root (rest)
sgdisk -n 1:0:+1024M -t 1:ef00 -c 1:"EFI System Partition" "$TARGET_DISK"
sgdisk -n 2:0:0      -t 2:8300 -c 2:"Gnomarchy Root" "$TARGET_DISK"

# Partprobe
partprobe "$TARGET_DISK"
sleep 2

# Determine partition names
if [[ "$TARGET_DISK" =~ [0-9]$ ]]; then
  EFI_PART="${TARGET_DISK}p1"
  ROOT_PART="${TARGET_DISK}p2"
else
  EFI_PART="${TARGET_DISK}1"
  ROOT_PART="${TARGET_DISK}2"
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

# Limine bootloader setup
limine bios-install "$TARGET_DISK" 2>/dev/null || true
mkdir -p /boot/EFI/BOOT
cp /usr/share/limine/BOOTX64.EFI /boot/EFI/BOOT/
efibootmgr --create --disk "$TARGET_DISK" --part 1 --loader '/EFI/BOOT/BOOTX64.EFI' --label 'Gnomarchy' 2>/dev/null || true

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
  git clone https://github.com/Gnomarchy/Gnomarchy.git "/mnt/home/$USERNAME/.local/share/gnomarchy"
fi

chown -R 1000:1000 "/mnt/home/$USERNAME/.local"

# Run Gnomarchy desktop installer inside chroot
echo -e "\n\033[1;36m==> Executing Gnomarchy Desktop & Environment Installer\033[0m"
arch-chroot -u "$USERNAME" /mnt /bin/bash -c "
  export GNOMARCHY_PATH=\"/home/$USERNAME/.local/share/gnomarchy\"
  export GNOMARCHY_CHROOT_INSTALL=1
  export USER=\"$USERNAME\"
  export HOME=\"/home/$USERNAME\"
  bash /home/$USERNAME/.local/share/gnomarchy/install.sh
"

echo -e "\n\033[1;32mInstallation complete! Unmounting filesystems...\033[0m"
umount -R /mnt
if [[ "$ENCRYPT_OPT" =~ ^[Yy]$ ]]; then
  cryptsetup close cryptroot 2>/dev/null || true
fi

echo -e "\nRebooting into your new Gnomarchy installation in 5 seconds (or press Enter)..."
read -t 5 -r || true
reboot
