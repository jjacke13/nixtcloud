# DO NOT modify this file!!

{ config, lib, pkgs, ... }:

{
  
  hardware.enableAllHardware = lib.mkForce false;
  hardware.enableRedistributableFirmware = lib.mkForce false;
  hardware.firmware = [ pkgs.raspberrypiWirelessFirmware ];
  boot.supportedFilesystems.zfs = lib.mkForce false;
  security.rtkit.enable = true;

  boot.kernelModules = [ "ntfs3" ];
  
  fileSystems."/" =
    { device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" "nodiratime" ];
    };
  
  networking.hostId = lib.mkForce null;
  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = "aarch64-linux";
  
  environment.etc."nixos/device.txt" = { 
    text = ''Rpi4'';
    mode = "0644";
    group = "wheel";
  };

  ######## SD-card longevity options #########
  imports =
    [ ./sd-card-friendly.nix
    ];
  ############################################

}