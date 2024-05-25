# TODO only partially isolate, don't live reload history when other shells save
# TODO git status
# TODO fzf fuzzy
# TODO isolation = false -> no session id is even generated... sad
# TODO nix command completion
$env.config = {
  show_banner: false

  history: {
    max_size: 10000000
    file_format: "sqlite"
    # Not writing history on enter is meh, but I want shells to only have
    # access to the history up to the point where it was started.
    # XXX: broken with sqlite. https://github.com/nushell/nushell/issues/7915
    sync_on_enter: false
    # but each shell should have an effective isolated buffer
    # XXX: todo this currently isolates completely, so no access to prev history at all.
    # instead, this should prevent live reloading history when other shells sync it.
    isolation: false
  }

  completions: {
    case_sensitive: false
    quick: true
    partial: true
    algorithm: "prefix"
    external: {
      enable: true
      max_results: 200
      completer: null
    }
  }

  cd: {
    abbreviations: true
  }

  shell_integration: true
}
