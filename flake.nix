{
  description = "A flake to produce sd-card images and nixos configurations running Nixtcloud for raspberry pi 4 and 5";
  
  #Nix-community cachix is needed if you want to build the image for raspberry pi 5. If you don't want to use it, 
  #the linux kernel will be built from source which takes a long time.
  nixConfig = {
      substituters = [ "https://nix-community.cachix.org" "https://cache.nixos.org" ];
	    trusted-public-keys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" 
                              "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];
  };
  
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    holesail.url = "github:jjacke13/holesail-nix";
    raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = { self, nixpkgs, holesail, raspberry-pi-nix, nixos-hardware, ... }:
  {
    nixosModules.state = { system.stateVersion = "24.11"; };

    packages.aarch64-linux = {
      Rpi4 = self.nixosConfigurations.Rpi4.config.system.build.sdImage;

      Rpi5 = self.nixosConfigurations.Rpi5.config.system.build.sdImage;
    };
    
    nixosConfigurations= {
      Rpi4 = nixpkgs.lib.nixosSystem {
        modules = [
          holesail.nixosModules.aarch64-linux.holesail
          ./base/configuration.nix
          ./hardware/Rpi4.nix
          nixos-hardware.nixosModules.raspberry-pi-4
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          self.nixosModules.state
        ];      
      };

      Rpi5 = nixpkgs.lib.nixosSystem {
        modules = [
          holesail.nixosModules.aarch64-linux.holesail
          ./base/configuration.nix
          ./hardware/Rpi5.nix
          raspberry-pi-nix.nixosModules.raspberry-pi
          raspberry-pi-nix.nixosModules.sd-image 
          self.nixosModules.state
        ];      
      };
    };
  };
}

