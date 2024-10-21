{
  description = "Base system for raspberry pi 4";
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-24.05";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-generators, ... }:
  {
    nixosModules = {
      system = {
        disabledModules = [
          "profiles/base.nix"
        ];

        system.stateVersion = "24.05";
      };  
      users = {
        users.users = {
          admin = {
            initialPassword = "admin";
            isNormalUser = true;
            extraGroups = [ "wheel" ];
          };
        };
      };
      
    };  
  
    packages.aarch64-linux = {
      sdcard = nixos-generators.nixosGenerate {
        system = "aarch64-linux";
        format = "sd-aarch64";
        modules = [
          ./starting-config.nix
          self.nixosModules.system
          self.nixosModules.users
                 
        ];
      };
    };
  };
}

