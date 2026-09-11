# Gaming

```bash
gnomarchy gaming install   # the whole stack
gnomarchy gaming status    # what is present
gnomarchy gaming proton    # manage Proton versions
```

Also under **Gaming** in the command center.

## What gets installed

From the official repositories:

- **Steam**, with the 32-bit libraries it needs
- **Lutris** for non-Steam games
- **Wine** and **winetricks** for Windows programs outside Proton
- **gamescope**, a micro-compositor for scaling and framerate control
- **GameMode**, which switches the CPU governor while a game runs
- **MangoHud** and **GOverlay** for the performance overlay
- **vkd3d** for Direct3D 12
- **umu-launcher**, which runs Proton outside Steam

From the AUR, or Flatpak when no AUR helper is present:

- **Proton-GE**, the community Proton build most games want
- **ProtonUp-Qt** to install and update Proton builds
- **Faugus Launcher** for Windows games outside Steam

## multilib

Steam and every 32-bit library live in the multilib repository. Gnomarchy
enables it during installation; if it is off, `gnomarchy gaming install`
enables it before doing anything else.

## Graphics drivers

The 32-bit Vulkan driver has to match your GPU, so the right one is detected
rather than all of them installed:

    NVIDIA   lib32-nvidia-utils
    AMD      lib32-vulkan-radeon
    Intel    lib32-vulkan-intel
    other    lib32-mesa

## Using it

**Steam**: enable Proton for all titles under Settings > Compatibility.

**Proton-GE**: after installing it with ProtonUp-Qt, restart Steam and pick the
GE build per game under Properties > Compatibility.

**MangoHud**: set the Steam launch options to

    MANGOHUD=1 %command%

**gamescope**: useful for games that handle resolution badly, e.g.

    gamescope -W 2560 -H 1440 -f -- %command%

**GameMode**: takes effect for users in the `gamemode` group. The installer
adds you; log out and back in for it to apply.

    gamemoderun %command%

## Which Proton to use

Valve's own Proton covers most of Steam. Proton-GE adds codecs and patches that
particular games need - reach for it when a title misbehaves under stock
Proton, not by default.
