{
  nom = {
    networking.hostName = "nom";
    deployment = {
      allowLocalDeployment = true;
      targetHost = null;
    };
    imports = [cell.nixosConfigurations.nom];
  };
}
