#!/bin/bash

gnomarchy_header "Detecting & Applying Hardware Profiles"

source "$GNOMARCHY_INSTALL/config/hardware/apple/fix-t2.sh"
source "$GNOMARCHY_INSTALL/config/hardware/intel/video-acceleration.sh"
source "$GNOMARCHY_INSTALL/config/hardware/nvidia.sh"

gnomarchy_step "Hardware profiling complete"
