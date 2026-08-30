# DO NOT modify this file!!

{ config, lib, pkgs, ... }:

{
  
  hardware.enableAllHardware = lib.mkForce false;
  hardware.enableRedistributableFirmware = lib.mkForce false;
  hardware.firmware = [ pkgs.raspberrypiWirelessFirmware ];
  boot.supportedFilesystems.zfs = lib.mkForce false;
  security.rtkit.enable = true;
  sdImage.compressImage = false;

  boot.kernelModules = [ "ntfs3" ];

  # nixos-hardware common/firmware.nix mkForces sd-image-aarch64s
  # populateFirmwareCommands away, and that is what used to write
  # u-boot-rpi4.bin plus a config.txt pointing at it. Without these two the
  # firmware partition has no bootable payload and a freshly flashed image
  # does not boot - an in-place switch survives only because the old FAT
  # partition is left untouched.
  hardware.raspberry-pi.firmware = {
    enable = true;
    uboot.enable = true;
  };

  fileSystems."/" =
    { device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" "nodiratime" ];
    };

  # The firmware activation script writes here only when it is a real mount
  # point; without this entry it logs a warning and skips.
  fileSystems."/boot/firmware" =
    { device = "/dev/disk/by-label/FIRMWARE";
      fsType = "vfat";
      options = [ "noatime" "nofail" ];
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