# DO NOT modify this file!!

{ config, lib, pkgs, ... }:

{
  raspberry-pi-nix.board = "bcm2712";

  boot.kernelModules = [ "ntfs3" ];

  fileSystems."/" =
    { device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" "nodiratime" ];
    };
  
  security.rtkit.enable = true;

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  environment.etc."nixos/device.txt" = { 
    text = ''Rpi5'';
    mode = "0644";
    group = "wheel";
  };
}