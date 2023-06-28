{
  # If the host defines microvms, ensure that our modules and
  # some boilerplate is imported automatically.
  meta.microvms.commonImports = [
    ../.
    {home-manager.users.root.home.minimal = true;}
  ];
}
