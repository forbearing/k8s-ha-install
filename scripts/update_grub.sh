#!/usr/bin/env bash
grub2-set-default "$(cat /boot/grub2/grub.cfg  | grep '^menuentry' | sed -n '1,1p' | awk -F "'" '{print $2}')"
