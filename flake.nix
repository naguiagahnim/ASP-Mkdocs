{
  description = "Flake pour dev MkDocs + Material";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    pkgs = nixpkgs.legacyPackages."x86_64-linux";
  in {
    devShells."x86_64-linux".default = pkgs.mkShell {
      buildInputs = with pkgs; [
        python314
        python314Packages.mkdocs
        python314Packages.mkdocs-material
        python314Packages.mkdocstrings
      ];

      shellHook = ''
        echo "Shell MKDocs prêt"
        echo "-- Utilisation --"
        echo "'mkdocs serve' pour démarrer le serveur MKDocs"
      '';
    };
  };
}
