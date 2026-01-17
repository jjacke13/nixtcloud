# DO NOT modify this file!!

{ config, lib, pkgs, ... }:

let
  # Pinned kernel version
  kernelVersion = "6.18.3";
  kernelSrc = pkgs.fetchurl {
    url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${kernelVersion}.tar.xz";
    hash = "sha256-eoh5FnuJxLrgd9bznE8hMHafBdva0qrZFK2rmvt9f5o=";
  };

  customKernel = pkgs.linuxManualConfig {
    version = kernelVersion;
    modDirVersion = kernelVersion;
    src = kernelSrc;
    configfile = ./kernel-rk3328-minimal.config;
    allowImportFromDerivation = true;
  };

  # U-Boot for NanoPi Neo3 (uses R2S config - identical hardware)
  ubootNanoPiNeo3 = pkgs.buildUBoot {
    defconfig = "nanopi-r2s-rk3328_defconfig";
    extraMeta.platforms = [ "aarch64-linux" ];
    BL31 = "${pkgs.armTrustedFirmwareRK3328}/bl31.elf";
    filesToInstall = [ "idbloader.img" "u-boot.itb" ];
  };

  # Filtered DTB package - uses pinned custom kernel (reduces /boot size)
  filteredDtbs = pkgs.stdenv.mkDerivation {
    name = "filtered-dtbs-nanopi-neo3";
    src = customKernel;
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/rockchip
      cp $src/dtbs/rockchip/rk3328-nanopi-r2s.dtb $out/rockchip/
    '';
  };
in
{
  boot = {
    kernelPackages = pkgs.linuxPackagesFor customKernel;

    initrd = {
      includeDefaultModules = false;
      compressor = "zstd";
      availableKernelModules = lib.mkForce [
        # Storage (SD card)
        "mmc_block"
        "dw_mmc"
        "dw_mmc_rockchip"
        "sdhci"
        "sdhci_of_dwcmshc"
        # Network (for headless SSH)
        "dwmac_rk"
        "stmmac"
        "stmmac_platform"
        "realtek"
      ];
    };

    kernelModules = lib.mkForce [];
  };

  hardware = {
    enableRedistributableFirmware = lib.mkForce false;
    firmware = lib.mkForce [];
    deviceTree = {
      name = "rockchip/rk3328-nanopi-r2s.dtb";
      package = lib.mkForce filteredDtbs;
    };
  };

  # SD image configuration
  sdImage = {
    compressImage = false;
    firmwareSize = 1;
    firmwarePartitionOffset = 8;
    populateFirmwareCommands = lib.mkForce "";
    postBuildCommands = ''
      dd if=${ubootNanoPiNeo3}/idbloader.img of=$img conv=fsync,notrunc bs=512 seek=64
      dd if=${ubootNanoPiNeo3}/u-boot.itb of=$img conv=fsync,notrunc bs=512 seek=16384
    '';
  };
  image.fileName = "nixos-nanopi-neo3-nixtcloud-${config.system.nixos.label}.img";

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
    options = [ "noatime" "nodiratime" ];
  };

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = "aarch64-linux";
  services.nextcloud.enableImagemagick = lib.mkForce false;
  networking.wireless.enable = lib.mkForce false;  # Nanopi-neo3 does not have WiFi
  networking.wireless.networks = lib.mkForce { };

  environment.etc."nixos/device.txt" = {
    text = ''Nanopi-neo3'';
    mode = "0644";
    group = "wheel";
  };

  ######## SD-card longevity options #########
  imports = [ ./sd-card-friendly.nix ];
  ############################################
}
