{
  nom = {
    networking.hostName = "nom";
    deployment = {
      allowLocalDeployment = true;
      targetHost = "192.168.1.183";
    };
    imports = [cell.nixosConfigurations.nom];
  };
}
