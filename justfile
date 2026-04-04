pre-emacs:
        cargo install cargo-cache tree-sitter-cli

default:
        sudo apt update
        sudo apt upgrade

emacs: default pre-emacs
    sudo apt install emacs-nox -y
    git clone --depth 1 https://github.com/plexus/chemacs2.git ~/.emacs.d
    git clone --depth 1 https://github.com/purcell/emacs.d.git ~/purcell
    rm -rf ~/purcell/site-lisp
    git clone --depth 1 https://github.com/rolojf/site-lisp.git ~/purcell/site-lisp
    rm ~/purcell/site-lisp/setup-wsl.el
    sed -i 's/^(require '\''setup-wsl)$/;; (require '\''setup-wsl)/' ~/purcell/site-lisp/init-local.el
    echo "(("default" . ((user-emacs-directory . "~/purcell"))))" >> ~/.emacs-profiles.el

# confirmar primero que npm (me parece extraño ) no esté en el PATH, corregir con
npm-en-path:
        echo 'export PATH="$(npm prefix -g)/bin:$PATH"' >> ~/.bash_profile

# confirmar primero que el path en /run/sshd no sea root como debe ser
setup-ssh:
    #!/bin/bash
    owner=$(stat -c '%U' /run/sshd)
    if [ "$owner" != "root" ]; then
        sudo chown root:root /run/sshd
        sudo chmod 755 /run/sshd
    else
        echo "Nothing has changed, the folder is already owned by root."
    fi
        sudo service ssh start
        service ssh status

primerito: default
     git config --global url."https://github.com/".insteadOf git@github.com:
     sudo apt install -y openssh-server
     sprite-env services create sshd --cmd /usr/sbin/sshd
     mkdir -p ~/.ssh
     chmod 700 ~/.ssh
     @read -p "Enter the text to add: " input; \
     echo "$input" >> ~/.ssh/authorized_keys
     chmod 600 ~/.ssh/authorized_keys

config-ccode:
    # por definir clonar .claude en mi github repo
