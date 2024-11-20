{
  description = "Base system for raspberry pi 4";
  inputs = {
    nixpkgs.url = "path:./nixpkgs-nixos-unstable";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-generators, ... }@inputs:
  {
    nixosModules = {
      system = {
        system.stateVersion = "24.05";
      };  
    };
    packages.aarch64-linux = {
      sdcard = nixos-generators.nixosGenerate {
        system = "aarch64-linux";
        format = "sd-aarch64";
        modules = [
          ./Rpi4/configuration.nix 
          self.nixosModules.system
        ];
      };
    };
  };
}

