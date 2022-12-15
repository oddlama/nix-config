{
  environment.etc."inputrc".text = ''
    # /etc/inputrc: initialization file for readline
    #
    # For more information on how this file works, please see the
    # INITIALIZATION FILE section of the readline(3) man page
    #
    # Quick dirty little note:
    #  To get the key sequence for binding, you can abuse bash.
    #  While running bash, hit CTRL+V, and then type the key sequence.
    #  So, typing 'ALT + left arrow' in Konsole gets you back:
    #    ^[[1;3D
    #  The readline entry to make this skip back a word will then be:
    #    "\e[1;3D" backward-word
    #
    # Customization note:
    #  You don't need to put all your changes in this file.  You can create
    #  ~/.inputrc which starts off with the line:
    #    $include /etc/inputrc
    #  Then put all your own stuff after that.
    #

    # do not bell on tab-completion
    set bell-style none

    set history-size -1

    set meta-flag on
    set input-meta on
    set convert-meta off
    set output-meta on

    # dont output everything on first line
    set horizontal-scroll-mode off


    # append slash to completed directories & symlinked directories
    set mark-directories on
    set mark-symlinked-directories on

    # dont expand ~ in tab completion
    set expand-tilde off

    # instead of ringing bell, show list of ambigious completions directly, also show up to 300 items before asking
    set show-all-if-ambiguous on
    set completion-query-items 300


    $if mode=emacs

    # for linux console and RH/Debian xterm
    # allow the use of the Home/End keys
    "\e[1~": beginning-of-line
    "\e[4~": end-of-line
    # map "page up" and "page down" to search history based on current cmdline
    "\e[5~": history-search-backward
    "\e[6~": history-search-forward
    # allow the use of the Delete/Insert keys
    "\e[3~": delete-char
    "\e[2~": quoted-insert

    # gnome / others (escape + arrow key)
    "\e[5C": forward-word
    "\e[5D": backward-word
    # konsole / xterm / rxvt (escape + arrow key)
    "\e\e[C": forward-word
    "\e\e[D": backward-word
    # gnome / konsole / others (control + arrow key)
    "\e[1;5C": forward-word
    "\e[1;5D": backward-word
    # aterm / eterm (control + arrow key)
    "\eOc": forward-word
    "\eOd": backward-word

    # konsole (alt + arrow key)
    "\e[1;3C": forward-word
    "\e[1;3D": backward-word

    # Chromebooks remap alt + backspace so provide alternative (alt + k)
    "\ek": backward-kill-word

    $if term=rxvt
    "\e[8~": end-of-line

    "\e[3^": kill-line
    "\e[3@": backward-kill-line
    $endif

    # for non RH/Debian xterm, can't hurt for RH/Debian xterm
    "\eOH": beginning-of-line
    "\eOF": end-of-line

    # for freebsd console
    "\e[H": beginning-of-line
    "\e[F": end-of-line

    # fix Home and End for German users
    "\e[7~": beginning-of-line
    "\e[8~": end-of-line

    # ctrl [+ shift] + del = kill line [backward]
    "\e[3;5~": kill-line
    "\e[3;6~": backward-kill-line
    $endif

    # Up and Down should search history based on current cmdline
    "\e[A": history-search-backward
    "\e[B": history-search-forward
  '';
}
