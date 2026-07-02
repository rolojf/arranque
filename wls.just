set shell := ["bash", "-cu"]

mount := "/home/a1rolo/s"
segundo := "segundo"

# Levanta sshd remoto, proxy + sshfs en pueue, y emacs -nw en el sprite.
emacs-remoto:
    ssh -O exit sprite 2>/dev/null || true
    sprite -s {{segundo}} x service ssh status >/dev/null 2>&1 || sprite -s {{segundo}} x sudo service ssh start
    pueue status >/dev/null 2>&1 || pueued -d
    pueue parallel 3
    (exec 3<>/dev/tcp/localhost/2000) 2>/dev/null && echo "proxy :2000 already up" || pueue add -- sprite -s {{segundo}} proxy 2000:22 8000
    timeout 30 bash -c 'until (exec 3<>/dev/tcp/localhost/2000) 2>/dev/null; do sleep 0.3; done' || { echo "proxy never came up on :2000"; exit 1; }
    mountpoint -q {{mount}} || sshfs -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=4 sprite: {{mount}}
    sprite -s {{segundo}} c
    emacs
