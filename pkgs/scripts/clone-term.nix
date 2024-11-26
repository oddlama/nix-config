# From: https://forge.lel.lol/patrick/nix-config/src/commit/77e9d0eaf356537131d33389cca15ffdd7bbefc2/pkgs/scripts/clone-term.nix
{
  writeShellApplication,
  ps,
  procps,
  xdotool,
  jq,
}:
writeShellApplication {
  name = "clone-term";
  runtimeInputs = [
    ps
    procps
    xdotool
    jq
  ];
  text = ''

    if [[ ''${XDG_CURRENT_DESKTOP-} == sway ]]; then
      PAREN=$(swaymsg -t get_tree | jq '.. | select(.type?) | select(.focused==true).pid')
    elif [[ ''${XDG_CURRENT_DESKTOP-} == Hyprland ]]; then
      PAREN=$(hyprctl activewindow -j | jq '.pid')
    else
      PAREN=$(xdotool getwindowfocus getwindowpid)
    fi

    MAXDEPTH=0
    SELECTED=0

    function recurse() {
      #shellcheck disable=SC2207
    	for i in $(pgrep -P "$1"); do

    		if [[ "$(readlink -e "/proc/''${i}/exe")" == *"zsh"* ]] && [[ $2 -gt $MAXDEPTH ]]; then
    			SELECTED="$i"
    			MAXDEPTH="$2"
    		fi
    		recurse "$i" "$(( $2 + 1 ))"
    	done
    }

    recurse "$PAREN" 1

    if [[ $SELECTED == 0 ]]; then
    	echo "not zsh found"
    	exit 1
    fi

    # kitty should be from user env
    kitty --detach -d "$(readlink "/proc/''${SELECTED}/cwd")"
  '';
}
