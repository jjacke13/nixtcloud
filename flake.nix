{
  description = "A flake to produce sd-card images and nixos configurations running Nixtcloud for Raspberry Pi 4, 5, and NanoPi NEO3";
  #The Raspberry Pi kernel (linux-rpi) is not on cache.nixos.org, so Rpi4 and
  #Rpi5 always compile it from source. The NanoPi NEO3 uses linuxManualConfig
  #with a custom .config, which can never be cached either.
  nixConfig = {
      substituters = [ "https://nix-community.cachix.org" "https://cache.nixos.org" ];
	    trusted-public-keys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" 
                              "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];
  };
  
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    holesail.url = "github:jjacke13/holesail-nix";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = { self, nixpkgs, holesail, nixos-hardware, ... }:
  {
    nixosModules.state = { system.stateVersion = "25.11"; };

    packages.aarch64-linux = {
      Rpi4 = self.nixosConfigurations.Rpi4.config.system.build.sdImage;
      Rpi5 = self.nixosConfigurations.Rpi5.config.system.build.sdImage;
      Nanopi-neo3 = self.nixosConfigurations.Nanopi-neo3.config.system.build.sdImage;
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
          nixos-hardware.nixosModules.raspberry-pi-5
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          self.nixosModules.state
        ];      
      };

      Nanopi-neo3 = nixpkgs.lib.nixosSystem {
        modules = [
          holesail.nixosModules.aarch64-linux.holesail
          ./base/configuration.nix
          ./hardware/Nanopi-neo3.nix
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          self.nixosModules.state
        ];
      };
    };
  };
}

