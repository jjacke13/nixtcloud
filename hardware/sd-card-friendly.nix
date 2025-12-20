{ config, ... }:
{
 ######## Less writting to the sd card #######
  services.journald.extraConfig = ''
    Storage=volatile
    RuntimeMaxUse=40M
    RuntimeMaxFileSize=5M
    SystemMaxUse=0
  '';
  # Move all frequent-write dirs into RAM
  fileSystems."/var/log" = {
    device = "logfs";
    fsType = "tmpfs";
    options = [ "mode=0755" "size=10M" ];
  };

  fileSystems."/var/tmp" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "mode=1777" "size=64M" ];
  };

  fileSystems."/var/lib/systemd" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "mode=0755" "size=32M" ];
  };

  fileSystems."/var/cache" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "mode=0755" "size=20M" ];
  };

  fileSystems."/root" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "mode=0700" "size=10M" ];
  };
  
  services.ntp.enable = true;
}