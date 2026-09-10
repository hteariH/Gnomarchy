#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="gnomarchy-linux"
iso_label="GNOMARCHY_$(date +%Y%m)"
iso_publisher="Gnomarchy Linux Project <https://github.com/Gnomarchy/Gnomarchy>"
iso_application="Gnomarchy Linux Live/Installation Media"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito'
           'uefi-ia32.systemd-boot.esp' 'uefi-x86_64.systemd-boot.esp'
           'uefi-ia32.systemd-boot.eltorito' 'uefi-x86_64.systemd-boot.eltorito')
arch="x86_64"
pacman_conf="pacman-online-stable.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/root/configurator"]="0:0:755"
  ["/usr/local/bin/gnomarchy-installer"]="0:0:755"
)
