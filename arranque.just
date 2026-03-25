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
