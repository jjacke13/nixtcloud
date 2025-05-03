# DO NOT modify this file!!

{ config, lib, pkgs, ... }:

{
  
  hardware.enableAllHardware = lib.mkForce false;
  boot.supportedFilesystems.zfs = lib.mkForce false;
  security.rtkit.enable = true;
  
  fileSystems."/" =
    { device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" "nodiratime" ];
    };
  
  networking.hostId = lib.mkForce null;
  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  environment.etc."nixos/device.txt" = { 
    text = ''Rpi4'';
    mode = "0644";
    group = "wheel";
  };
}