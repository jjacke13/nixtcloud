{
  description = "A flake to produce sd-card images and nixos configurations running Nixtcloud for raspberry pi 4 and 5";
  
  #Nix-community cachix is needed if you want to build the image for raspberry pi 5. If you don't want to use it, 
  #the linux kernel will be built from source which takes a long time.
    
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    holesail.url = "github:jjacke13/holesail-nix";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix";
  };

  outputs = { self, nixpkgs, nixos-generators, holesail, nixos-hardware, raspberry-pi-nix, ... }:
  {
    nixosModules.state = { system.stateVersion = "24.11"; };

    packages.aarch64-linux = {
      Rpi4 = nixos-generators.nixosGenerate {
        system = "aarch64-linux";
        format = "sd-aarch64";
        modules = [
          nixos-hardware.nixosModules.raspberry-pi-4
          ./Rpi4/configuration.nix
          holesail.nixosModules.aarch64-linux.holesail
          self.nixosModules.state
        ];
      };

      Rpi5 = self.nixosConfigurations.Rpi5.config.system.build.sdImage;
    };
    
    nixosConfigurations.Rpi4 = nixpkgs.lib.nixosSystem {
      modules = [
        nixos-hardware.nixosModules.raspberry-pi-4
        holesail.nixosModules.aarch64-linux.holesail
        ./Rpi4/configuration.nix 
        self.nixosModules.state
      ];      
    };

    nixosConfigurations.Rpi5 = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        raspberry-pi-nix.nixosModules.raspberry-pi
        raspberry-pi-nix.nixosModules.sd-image
        holesail.nixosModules.aarch64-linux.holesail
        ./Rpi5/configuration.nix 
        self.nixosModules.state
      ];      
    };
  };
}

