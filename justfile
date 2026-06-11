pre-emacs:
        cargo install cargo-cache tree-sitter-cli
        npm install -g @agentclientprotocol/claude-agent-acp
        npm install lamdera@latest elm-test-rs elm@latest-0.19.1 elm-format @elm-tooling/elm-language-server prettier
        sudo apt install hunspell hunspell-en-us hunspell-es

default:
        sudo apt update
        sudo apt upgrade
        cargo install-update -a -c /.sprite/languages/rust/cargo
        npm -g update
        npm -g upgrade

emacs: default pre-emacs
    sudo apt install emacs ripgrep -y
    git clone --depth 1 https://github.com/plexus/chemacs2.git ~/.emacs.d
    git clone --depth 1 https://github.com/purcell/emacs.d.git ~/purcell
    rm -rf ~/purcell/site-lisp
    git clone --depth 1 https://github.com/rolojf/site-lisp.git ~/purcell/site-lisp
    rm ~/purcell/site-lisp/setup-wsl.el
    sed -i 's/^(require '\''setup-wsl)$/;; (require '\''setup-wsl)/' ~/purcell/site-lisp/init-local.el
    echo "(("default" . ((user-emacs-directory . "~/purcell"))))" >> ~/.emacs-profiles.el
    echo 'export EDITOR="emacsclient -nw"' >> ~/.bashrc

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
     cargo install cargo-update
     mkdir -p ~/.local/share/Trash/{files,info}
     sudo apt install trash-cli
     ln -s ~/arranque/justfile ~/.justfile
     ln -s ~/arranque/.bash_profile ~/

config-ccode:
    # por definir clonar .claude en mi github repo

# install hermes-agent (git method); interactive — answer setup-hermes.sh prompts
hermes-install:
    #!/bin/bash
    set -euo pipefail
    echo ">>> Cloning hermes-agent and running its setup."
    echo ">>> Prompts: Y to ripgrep; wizard Y/N as you prefer (it configures LLM keys + Telegram)."
    mkdir -p ~/.hermes
    git clone --depth 1 https://github.com/NousResearch/hermes-agent.git ~/.hermes/hermes-agent
    cd ~/.hermes/hermes-agent
    ./setup-hermes.sh
    echo ""
    echo ">>> Next, configure the basics ('hermes setup' wizard, or edit ~/.hermes/.env):"
    echo ">>>   OPENROUTER_API_KEY, TELEGRAM_BOT_TOKEN, TELEGRAM_ALLOWED_USERS, TELEGRAM_HOME_CHANNEL"
    echo ">>> Do NOT set TELEGRAM_WEBHOOK_* — polling mode is required for wake-on-demand."
    echo ">>> Then run: just hermes-wake-config"

# wake-on-demand: waker service + task hold + pre_llm_call hook. Run AFTER keys are set.
hermes-wake-config:
    #!/bin/bash
    set -euo pipefail
    mkdir -p ~/bin ~/.hermes/agent-hooks ~/.hermes/logs
    cp {{justfile_directory()}}/hermes/start-hermes.sh ~/bin/
    cp {{justfile_directory()}}/hermes/start-waker.sh ~/bin/
    cp {{justfile_directory()}}/hermes/waker.py ~/bin/
    cp {{justfile_directory()}}/hermes/refresh-task.sh ~/.hermes/agent-hooks/
    chmod +x ~/bin/start-hermes.sh ~/bin/start-waker.sh ~/.hermes/agent-hooks/refresh-task.sh
    ~/.hermes/hermes-agent/venv/bin/python {{justfile_directory()}}/hermes/configure-hooks.py
    sprite-env services create hermes --cmd "$HOME/bin/start-hermes.sh"
    sprite-env services create waker --cmd "$HOME/bin/start-waker.sh" --http-port 8080
    echo ">>> Verifying — waker response (expect 'awake'):"
    curl -s http://localhost:8080/
    echo ">>> Services:"
    sprite-env services list
    echo ">>> Task hold (expect hermes-active with expires_at):"
    curl -s --unix-socket /.sprite/api.sock -H "Host: sprite" http://sprite/v1/tasks
    echo ""
    echo ">>> Manual steps left:"
    echo ">>>  1. From your machine, set the sprite URL auth to public (sprite CLI / dashboard)."
    echo ">>>  2. Bookmark the sprite_url below on the phone (Firefox):"
    sprite-env info
    echo ">>>  3. Checkpoint: sprite-env checkpoints create --comment 'hermes wake-on-demand ready'"
    echo ">>> Usage: send a Telegram message, THEN tap the bookmark; the reply arrives after wake."
