#!/bin/sh -fux

cri_info()
{
    if command -v podman >/dev/null; then
        cri_bin='podman'
    elif command -v docker >/dev/null; then
        cri_bin='docker'
    else
        return
    fi

    "${cri_bin}" system info
    "${cri_bin}" system df
}

git_info()
{
    git rev-parse --show-toplevel >/dev/null 2>&1 || return

    git config list
}

hw_info()
{
    free -h
    lscpu
}

net_info()
{
    if command -v networkctl >/dev/null; then
        networkctl list
        networkctl status
    elif command -v nmcli >/dev/null; then
        nmcli device status
        nmcli connection show
    elif command -v ip >/dev/null; then
        ip -brief link show
        ip -brief address show
    else
        (
          { set +x; } 2>/dev/null

          for netdev in $(set +f; echo /sys/class/net/*); do
              # Skip special files like bonding_masters
              [ ! -L "${netdev}" ] && continue

              # veth
              [ -d "${netdev}"/master ] && continue

              nic=${netdev##*/}
              ip -brief link show dev "${nic}"
              ip address show dev "${nic}"
          done
        )
    fi

    resolvectl status || cat /etc/resolv.conf
}

storage_info()
{
    lsblk

    findmnt --real --output='SOURCE,FSTYPE,SIZE,USED,AVAIL,USE%,TARGET' || df -h
}

sys_info()
{
    id
    ls -Ahl
    set

    uptime
    cat /proc/cmdline

    hostnamectl status || { hostname; cat /etc/os-release; }
    localectl status || locale
    timedatectl status || date

    loginctl list-sessions || lastlog2 -a || lastlog

    journalctl --list-boots || last reboot
}

sys_info
git_info
hw_info
net_info
storage_info
cri_info

exit

# vi: set ft=sh et sw=4 ts=4:
