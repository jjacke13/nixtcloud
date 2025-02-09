# DO NOT modify this file!!

{ config, lib, pkgs, ... }:

{
  hardware.enableRedistributableFirmware = true;
  
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = lib.mkDefault true;
  
  boot.initrd.availableKernelModules = [
      "usbhid"
      "usb_storage"
      "vc4"
      "pcie_brcmstb" # required for the pcie bus to work
      "reset-raspberrypi" # required for vl805 firmware to load
  ];
  
  fileSystems."/" =
    { device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
    };

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
