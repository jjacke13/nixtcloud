# DO NOT modify this file!!

{ config, lib, pkgs, ... }:

{
  # The board profile (nixos-hardware.nixosModules.raspberry-pi-5) supplies the
  # linux-rpi kernel, the bcm2712 device-tree filter, and the RP1/PCIe initrd
  # modules. What it does not do is put anything bootable on the firmware
  # partition - that is the module below.
  hardware.raspberry-pi.firmware = {
    # Repopulate /boot/firmware on every switch, so an OTA update that changes
    # config.txt, a device tree or U-Boot actually reaches the FAT partition.
    enable = true;
    # The GPU firmware cannot read ext4, so it chainloads U-Boot, which then
    # reads /boot/extlinux/extlinux.conf from the root filesystem. Without
    # this the firmware partition holds no bootable payload at all: the
    # firmware module mkForces sd-image-aarch64's populateFirmwareCommands
    # away, and that is what used to supply u-boot-rpi4.bin.
    uboot.enable = true;
  };

  # PCIe is disabled by default on the Pi 5, so an NVMe drive on an M.2 HAT
  # never enumerates without this. Root stays on the SD card; the drive is
  # picked up by mounter.sh as ordinary storage, the same as a USB disk.
  # Add pciex1_gen=3 here for Gen 3 speeds - officially uncertified, and some
  # HATs are unstable with it, so it is left off.
  hardware.raspberry-pi.configtxt.settings.pi5.dtparam = [ "pciex1" ];

  boot.kernelModules = [ "ntfs3" ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
    options = [ "noatime" "nodiratime" ];
  };

  # hardware.raspberry-pi.firmware writes here only when it is a real mount
  # point; without this entry the activation script logs a warning and skips.
  fileSystems."/boot/firmware" = {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
    options = [ "noatime" "nofail" ];
  };

  security.rtkit.enable = true;
  sdImage.compressImage = false;

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  environment.etc."nixos/device.txt" = {
    text = ''Rpi5'';
    mode = "0644";
    group = "wheel";
  };

  ######## SD-card longevity options #########
  imports =
    [ ./sd-card-friendly.nix
    ];
  ############################################
}
