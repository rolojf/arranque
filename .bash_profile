echo "[.bash_profile loaded]"

# Source .bashrc for interactive shell settings
[ -r ~/.bashrc ] && . ~/.bashrc

# Add dirs the sprite console has but SSH doesn't
# Prepend a dir to PATH only if not already present
prepend_path() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="$1:$PATH" ;;
    esac
}

prepend_path "$HOME/.local/bin"
prepend_path "/.sprite/bin"
export PATH
