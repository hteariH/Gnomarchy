#!/bin/bash

gnomarchy_header "System Pre-Flight Check"
gnomarchy_substep "Target User: $USER"
gnomarchy_substep "Install Destination: $GNOMARCHY_PATH"
gnomarchy_substep "Kernel: $(uname -r)"
gnomarchy_substep "Chroot Mode: ${GNOMARCHY_CHROOT_INSTALL:-false}"
