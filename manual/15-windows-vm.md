# Windows VM

```bash
gnomarchy windows setup
gnomarchy windows start
gnomarchy windows status
```

Creates and runs a hardware-accelerated Windows 11 virtual machine with KVM,
VirtIO drivers and a software TPM 2.0, which Windows 11 requires.

## What you need

- A CPU with virtualisation enabled in firmware
- Enough disk for the image
- A Windows 11 ISO, which you supply

## Notes

`setup` is a one-off; afterwards `start` boots the existing machine. VirtIO
gives usable disk and network performance, and `swtpm` satisfies the TPM check
without disabling it.

For a single Windows application, consider a web app or a Wine prefix first - a
whole VM is a lot of machinery for one program.
