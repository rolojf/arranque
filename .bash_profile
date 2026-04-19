echo "[.bash_profile loaded]"

# Source .bashrc for interactive shell settings
[ -r ~/.bashrc ] && . ~/.bashrc

# Add dirs the sprite console has but SSH doesn't
export PATH="/.sprite/bin:$HOME/.local/bin:$PATH"
