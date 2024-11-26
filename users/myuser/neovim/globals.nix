{
  programs.nixvim.opts = {
    # -------------------------------------------------------------------------------------------------
    # General
    # -------------------------------------------------------------------------------------------------

    undolevels = 1000000; # Set maximum undo levels
    undofile = true; # Enable persistent undo which persists undo history across vim sessions
    updatetime = 300; # Save swap file after 300ms
    mouse = "a"; # Enable full mouse support

    # -------------------------------------------------------------------------------------------------
    # Editor visuals
    # -------------------------------------------------------------------------------------------------

    termguicolors = true; # Enable true color in terminals

    splitkeep = "screen"; # Try not to move text when opening/closing splits
    wrap = false; # Do not wrap text longer than the window's width
    scrolloff = 2; # Keep 2 lines above and below the cursor.
    sidescrolloff = 2; # Keep 2 lines left and right of the cursor.

    number = true; # Show line numbers
    cursorline = true; # Enable cursorline, colorscheme only shows this in number column
    wildmode = [
      "list"
      "full"
    ]; # Only complete the longest common prefix and list all results
    fillchars = {
      stlnc = "─";
    }; # Show separators in inactive window statuslines

    # FIXME: disabled because this really fucks everything up in the terminal.
    title = false; # Sets the window title
    # titlestring = "%t%( %M%)%( (%{expand(\"%:~:.:h\")})%) - nvim"; # The format for the window title

    # -------------------------------------------------------------------------------------------------
    # Editing behavior
    # -------------------------------------------------------------------------------------------------

    whichwrap = ""; # Never let the curser switch to the next line when reaching line end
    ignorecase = true; # Ignore case in search by default
    smartcase = true; # Be case sensitive when an upper-case character is included

    expandtab = false;
    tabstop = 4; # Set indentation of tabs to be equal to 4 spaces.
    shiftwidth = 4;
    softtabstop = 4;
    shiftround = true; # Round indentation commands to next multiple of shiftwidth

    # r = insert comment leader when hitting <Enter> in insert mode
    # q = allow explicit formatting with gq
    # j = remove comment leaders when joining lines if it makes sense
    formatoptions = "rqj";

    # Allow the curser to be positioned on cells that have no actual character;
    # Like moving beyond EOL or on any visual 'space' of a tab character
    virtualedit = "all";
    selection = "old"; # Do not include line ends in past the-line selections
    smartindent = true; # Use smart auto indenting for all file types

    # Wait 500 milliseconds for characters to arrive in a mapped sequence.
    # Afterwards, which-key will be opened
    timeout = true;
    timeoutlen = 500;
    # Wait 20 (instead of 50) milliseconds for characters to arrive in the TUI.
    ttimeout = true;
    ttimeoutlen = 20;

    grepprg = "rg --vimgrep --smart-case --follow"; # Replace grep with ripgrep
  };
}
