let
  issue_text = ''
    \d  \t
    This is \e{cyan}\n\e{reset} [\e{lightblue}\l\e{reset}] (\s \m \r)
  '';
in {
  environment.etc."issue".text = issue_text;
  environment.etc."issue.logo".text = issue_text;
}
