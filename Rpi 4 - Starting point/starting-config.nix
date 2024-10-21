{ config, lib, pkgs, modulesPath, ... }:
{
  networking.hostName = "nixtcloud"; # Define your hostname.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.
  
  networking.firewall.enable = false;
  
  environment.systemPackages = with pkgs; [
        pkgs.wget
        pkgs.git
        pkgs.openssh
        pkgs.avahi
        pkgs.nssmdns
  ];

  services.avahi.enable = true;
  services.avahi.publish.enable = true;
  services.avahi.hostName = "nixtcloud";
  services.avahi.nssmdns4 = true; 
  services.avahi.publish.userServices = true;
  
  services.openssh.enable = true;
  
  nix.settings = {
	        experimental-features = "flakes";
  };
}
