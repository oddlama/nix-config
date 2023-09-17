$env.config = {
  show_banner: false

  history: {
    max_size: 10000000
    file_format: "sqlite"
    # Write history on enter
    sync_on_enter: true
    # but each shell should have an effective isolated buffer
    isolation: true
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
}
