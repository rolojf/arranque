set shell := ["bash", "-cu"]

segundo := "segundo"

# Levanta sshd remoto, proxy en pueue + sshfs montado en la carpeta elegida
default:
    #!/usr/bin/env bash
    set -euo pipefail
    read -rp "Sprite name: " sprite_name
    read -rp "Local SSH port: " port
    read -erp "Local SSHFS mount folder [$HOME/s]: " mount_dir
    mount_dir="${mount_dir:-$HOME/s}"
    case "$mount_dir" in
      '~') mount_dir="$HOME" ;;
      '~/'*) mount_dir="$HOME/${mount_dir:2}" ;;
    esac
    mkdir -p "$mount_dir"
    ssh -O exit sprite 2>/dev/null || true
    sprite -s "$sprite_name" x service ssh status >/dev/null 2>&1 || sprite -s "$sprite_name" x sudo service ssh start
    pueue status >/dev/null 2>&1 || pueued -d
    pueue parallel 3
    if (exec 3<>/dev/tcp/localhost/"$port") 2>/dev/null; then
      echo "proxy :$port already up"
    else
      pueue add -- sprite -s "$sprite_name" proxy "$port:22" 8000
    fi
    timeout 30 bash -c 'until (exec 3<>/dev/tcp/localhost/"$0") 2>/dev/null; do sleep 0.3; done' "$port" || {
      echo "proxy never came up on :$port"
      exit 1
    }
    mountpoint -q "$mount_dir" || \
      sshfs -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=4 \
        -p "$port" sprite@localhost: "$mount_dir"
    sprite -s "$sprite_name" c


setup-sprite-ssh-key:
    #!/bin/bash
    set -euo pipefail

    read -rp "Sprite name: " sprite_name

    pubkey_file="$HOME/.ssh/id_ed25519.pub"

    if [ ! -f "$pubkey_file" ]; then
      echo "Missing $pubkey_file"
      exit 1
    fi

    cat "$pubkey_file" | sprite -s "$sprite_name" exec -- bash -lc '
    set -euo pipefail
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    cat > ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    '

    echo "Installed $pubkey_file into Sprite: $sprite_name"