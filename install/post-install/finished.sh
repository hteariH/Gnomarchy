#!/bin/bash

clear
echo -e "\033[1;32m"
cat <<'EOF'
  ██████╗ ███╗   ██╗ ██████╗ ███╗   ███╗ █████╗ ██████╗  ██████╗██╗  ██╗██╗   ██╗
 ██╔════╝ ████╗  ██║██╔═══██╗████╗ ████║██╔══██╗██╔══██╗██╔════╝██║  ██║╚██╗ ██╔╝
 ██║  ███╗██╔██╗ ██║██║   ██║██╔████╔██║███████║██████╔╝██║     ███████║ ╚████╔╝ 
 ██║   ██║██║╚██╗██║██║   ██║██║╚██╔╝██║██╔══██║██╔══██╗██║     ██╔══██║  ╚██╔╝  
 ╚██████╔╝██║ ╚████║╚██████╔╝██║ ╚═╝ ██║██║  ██║██║  ██║╚██████╗██║  ██║   ██║   
  ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝   ╚═╝   
EOF
echo -e "\033[0m"
echo -e "\033[1;36mGnomarchy Installation Complete!\033[0m\n"
echo -e "Key features ready:"
echo -e "  - \033[1mGNOME 50 + GDM\033[0m on pure Arch Linux"
echo -e "  - \033[1mWindow Tiling\033[0m: zones on \033[33mCtrl + drag\033[0m; tree tiling with \033[33mgnomarchy tiling enable\033[0m"
echo -e "  - \033[1mDeveloper Terminal\033[0m: Press \033[33mSuper + Return\033[0m for GNOME Terminal"
echo -e "  - \033[1mTheme Switcher\033[0m: Run \033[33mgnomarchy theme set <Theme>\033[0m"
echo -e "  - \033[1mBtrfs Rollbacks\033[0m: Run \033[33mgnomarchy snapshot create <name>\033[0m"
if [ -n "$GNOMARCHY_CHROOT_INSTALL" ]; then
  echo -e "\n\033[1;32mInstallation fully completed! Preparing system reboot...\033[0m"
else
  echo -e "\nPlease reboot your machine to start your Gnomarchy session."
fi
