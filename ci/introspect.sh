#!/bin/sh -efux

sys_info()
{
    id

    uptime
    free -h
    lscpu

    cat /etc/os-release
    cat /proc/cmdline

    set

    ls -Ahl
    last reboot

    podman system info
}

net_info()
{
    (
      { set +x; } 2>/dev/null

      for netdev in $(find /sys/class/net); do
          # Skip special files like bonding_masters
          [ ! -L "${netdev}" ] && continue

          # veth
          [ -d "${netdev}"/master ] && continue

          nic=${netdev##*/}
          ip -br link show dev "${nic}"
          ip address show dev "${nic}"
      done
    )

    if command -v nmcli >/dev/null; then
        nmcli device status
        nmcli connection show
    else
        ip -brief link show
        ip -brief address show
    fi
}

storage_info()
{
    lsblk

    findmnt --real --output='SOURCE,FSTYPE,SIZE,USED,AVAIL,USE%,TARGET'

    podman system df
}

sys_info
net_info
storage_info

exit

# vi: set ft=sh et sw=4 ts=4:
