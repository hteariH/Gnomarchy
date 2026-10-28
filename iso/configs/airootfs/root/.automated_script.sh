#!/usr/bin/env bash
# Run by archiso's .zlogin on every login shell of the live medium. The
# installer itself lives in the repository copy at /root/gnomarchy, so it is
# always the same revision as the configuration it installs.
#
# tty1 only: archiso logs in there automatically, and a second login on
# another console, for debugging, must not start a second installer.
[[ "$(tty)" == /dev/tty1 ]] || exit 0
# bash, not a direct exec: mkarchiso copies airootfs without preserving modes.
exec bash /root/gnomarchy/iso/installer/gnomarchy-install
