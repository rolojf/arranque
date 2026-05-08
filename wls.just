set shell := ["bash", "-cu"]

mount := "/home/a1rolo/s"

# Levanta sshd remoto, proxy + sshfs en pueue, y emacs -nw en el sprite.
emacs-remoto:
    sprite x service ssh status >/dev/null 2>&1 || sprite x sudo service ssh start
    pueue status >/dev/null 2>&1 || pueued -d
    sleep 1
    pueue parallel 4
    pueue add -- sprite -s segundo proxy 2000:22 8000
    sleep 3
    pueue add -- sshfs -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3 -p 2000 sprite@segundo: {{mount}}
    sprite -s segundo x --tty -- emacs -nw
