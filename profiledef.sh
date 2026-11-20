#!/usr/bin/env bash
# BISON profile

iso_name="bison"
iso_label="BISON_202611"
iso_publisher="BISON Linux <https://bisonlinux.org>"
iso_application_id="BISON Linux Live/Install"
iso_version="0.1"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.grub')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/root/.gnupg"]="0:0:700"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/Installation_guide"]="0:0:755"
  ["/usr/local/bin/bison-install"]="0:0:755"
  ["/usr/local/bin/bison-live"]="0:0:755"
  ["/usr/local/bin/bison-install-desktop"]="0:0:755"
  ["/root/Desktop/bison-install.desktop"]="0:0:755"
)