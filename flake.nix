{
  description = "Base system for raspberry pi 4";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    holesail.url = "github:jjacke13/holesail-nix";
  };

  outputs = { self, nixpkgs, nixos-generators, ... }@inputs:
  {
    packages.aarch64-linux = {
      Rpi4 = nixos-generators.nixosGenerate {
        system = "aarch64-linux";
        format = "sd-aarch64";
        specialArgs = { inherit inputs;};
        modules = [
          ./Rpi4/configuration.nix 
          {system.stateVersion = "24.11";}
        ];
      };
    };
    nixosConfigurations.nixtcloud = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs;};
      modules = [
        ./Rpi4/configuration.nix 
        {system.stateVersion = "24.11";}
      ];      
    };
  };
}


