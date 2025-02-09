# DO NOT modify this file!!

{ config, lib, pkgs, ... }:

{
  raspberry-pi-nix.board = "bcm2712";
  
  security.rtkit.enable = true;

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
