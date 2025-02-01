{ config, lib, pkgs, ... }:
let
  name = "nixtcloud";
in
{
  imports =
    [ ./hardware-configuration.nix
      ./nextcloud.nix
    ];

  # Use the extlinux boot loader. (NixOS wants to enable GRUB by default)
  boot.loader.grub.enable = false;
  # Enables the generation of /boot/extlinux/extlinux.conf
  boot.loader.generic-extlinux-compatible.enable = true;
  networking.hostName = name; 
  
  #### You can define your wireless network here if you don't want to use ethernet cable.
  #networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  #networking.wireless.networks = { SSID = { psk = "your_pass"; };
  #};   

  # Set your time zone.
  time.timeZone = "auto";
  
  ########## Most probably you don't need and don't want to change the nix settings below #########
  nix.settings = {
	  experimental-features = "nix-command flakes";
	  auto-optimise-store = true;
    require-sigs = false;
  };
  nix.gc = {
	  automatic = true;
	  dates = "weekly";
	  options = "--delete-older-than 5d";
  };
  ##########################################################################################
 
  ### DO NOT CHANGE the username. After the system is installed, you can change the password with 'passwd' command.
   users.users.admin = {
     isNormalUser = true;
     extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
     initialPassword = "admin";
   };
  
  ### If you know what the following line does, you can uncomment it ;)
  #security.sudo.wheelNeedsPassword = false;

  ###### Packages that are available systemwide. Most probably you don't need to change this. ######
  environment.systemPackages = [
      pkgs.htop
      pkgs.wget
      pkgs.avahi
      pkgs.nssmdns  
      pkgs.cron
  ];  

  ### This part reboots the system every day at 2:00 AM. You can change the time if you want, or disable it entirely. 
  ### I added this because I think it is good to reboot once a day to keep the system healthy.
  services.cron.enable = true;
  services.cron.systemCronJobs = ["0 2 * * *    root    /run/current-system/sw/bin/reboot"];
  
  ########## SSH & Security ##########
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "no";
  users.users.admin.openssh.authorizedKeys.keys = [ "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCjqJudIladr0clAOCeyK4W2+hESdm1kCp9xKp2ssc3mKdagLPjW1Ve5aSnsylVhE5boi+EMDKMvvmw3Ac/qpqd60pBchBR0Ex5NZiOg8BVp99aBOOfJD2KVdVpPkAM9wPAZU46EFMLd5QGJ0y88y72SF22Mo3tBYk516GuLoXgzNNSQT51DUSMey2Sa5euizBNnHwZntlkPNeuH4/TcFhR9PDZ4KxKMfu1y7rUhbHd0XJGRNNlPGFtiYZOssvdOvZqm+BHbUzSxvfALn5QA1ZgUglpEcEIrWD4H5NDjjoE0Z1VQ1pyYF4frV2e8l3sJr1Hl4xT6Y2bPyJsBDUmOtTma0r9lUzoMxblqW5wGnn+rPFlNJEwK21BgJ/SidWGkLA2AxsweWq6Gw/S1RAzkT+oud5t69TTelZQNMbiN0L69HkoZSIcjTQX7Wp3Y9cWa+rvJIgkDPlhhg8AruG+kwSIxVDwrwhRjSCg9v5/IxPU5fiyEwCRfdi69WDkcN6PjOT+9Lkufidta81TMN5PCsSWUjaVENk6ZEjzD8CpQ072ELpyCIj21zp3TDA/oSckJUSO53d8dZhYCsBzlw/duNy+3n06eBvy7keN7MMqQPqhIFQZHFEh9ymy8B7qnJ07W0Iha82npXnwtc2ZyQNy16MPE0TmUF2/03/l89t2BNcTQQ=="];
  networking.firewall.allowedTCPPorts = [ 22 80 ];
  networking.firewall.enable = true;
  #####################################
  
  #### DON'T CHANGE ANYTHING BELOW THIS LINE UNLESS YOU ABSOLUTELY KNOW WHAT YOU ARE DOING ###

  ########## AVAHI ########## 
  services.avahi = {
    enable = true;
    hostName = name;
    nssmdns4 = true; 
    reflector = true;
    openFirewall = true;
    publish.userServices = true;
    publish.enable = true;
    publish.domain = true;
    publish.addresses = true;
  };
  ###########################

  ###### System services ######

  #### This service initializes the system and checks stuff after each reboot. ####
  systemd.services.startup = {
    description = "Startup";
    wantedBy = [ "multi-user.target" ];
    after = ["network.target" "nextcloud-setup.service"];
    enable = true;
    path = [ pkgs.coreutils pkgs.qrencode pkgs.pwgen ];
    script = ''
          /run/current-system/sw/bin/nextcloud-occ app:enable files_external
          if [ ! -d /mnt/Public ]; then
              mkdir -p /mnt/Public
              chown -R nextcloud:nextcloud /mnt/Public
          fi      
		      storages=$(/run/current-system/sw/bin/nextcloud-occ files_external:list | /run/current-system/sw/bin/awk '/[0-9]+/ {print $2}')
		      for i in $storages; do
    			    /run/current-system/sw/bin/nextcloud-occ files_external:delete -y $i
		      done
          if [ ! -f /var/lib/nextcloud/data/admin/files/rebooter.txt ]; then
              touch /var/lib/nextcloud/data/admin/files/rebooter.txt
              chown nextcloud:nextcloud /var/lib/nextcloud/data/admin/files/rebooter.txt
              /run/current-system/sw/bin/nextcloud-occ files:scan --path=/admin/files
          fi
          if [ ! -f /var/lib/nextcloud/data/admin/files/remote.txt ]; then
              touch /var/lib/nextcloud/data/admin/files/remote.txt
              pwgen -1 -N 1 -s 35 | tr -d '\n' > /var/lib/nextcloud/data/admin/files/remote.txt
              qrencode -o /var/lib/nextcloud/data/admin/files/remote.jpg -r /var/lib/nextcloud/data/admin/files/remote.txt -s 10
              chown nextcloud:nextcloud /var/lib/nextcloud/data/admin/files/remote.txt
              chown nextcloud:nextcloud /var/lib/nextcloud/data/admin/files/remote.jpg
              /run/current-system/sw/bin/nextcloud-occ files:scan --path=/admin/files
          fi
          if [ ! -f /mnt/Public/public.txt ]; then
              touch /mnt/Public/public.txt
              pwgen -1 -N 1 -s 35 | tr -d '\n' > /mnt/Public/public.txt
              qrencode -o /mnt/Public/public.jpg -r /mnt/Public/public.txt -s 10
              chown -R nextcloud:nextcloud /mnt/Public
          fi
          /run/current-system/sw/bin/nextcloud-occ files_external:create "/Public" local null::null -c datadir="/mnt/Public"
    '';
    serviceConfig.Type = "oneshot";
    before = ["mymnt.service" "p2pmagic.service" "p2public.service" "rebooter.service"];
    onSuccess = ["mymnt.service" "p2pmagic.service" "p2public.service" "rebooter.service"];
  };  
  ############################################################################

  ### The following service automounts external usb devices with correct permissions and creates the corresponding Nextcloud external storages.###### 
  systemd.services.mymnt = {
    enable = true;
    path = [ pkgs.util-linux pkgs.gawk pkgs.exfatprogs];
    serviceConfig = {
		  Type = "simple";
		  ExecStart = "${pkgs.bash}/bin/bash /etc/nixos/mounter.sh";
		  Restart = "always";
		  RestartSec = "30";  
	  };
  };
  ################################################################################
  
  #### The following sevice enables Holesail to do its magic ####
  services.holesail-server.p2pmagic = {
  	enable = true;
  	port = 80;
  	connector-file = "/var/lib/nextcloud/data/admin/files/remote.txt";
  };
  ###############################################################################
  
  ### The following service enables the share of the Public folder with Holesail ####
  services.holesail-filemanager.p2public = {
  	enable = true;
  	connector-file = "/mnt/Public/public.txt";
    path = "/mnt/Public";
    username = "test";
    password = "test";
    role = "user";
  };
  ##############################################################################
  
  ##### This service reboots the system if the rebooter.txt file gets deleted. On startup, it gets created again ####   
  systemd.services.rebooter = {
    description = "rebooter";
    enable = true;
    path = [  ];
    script = ''
          if [ ! -f /var/lib/nextcloud/data/admin/files/rebooter.txt ]; then
            reboot
          fi
    '';
    serviceConfig.Type = "simple";
    serviceConfig.Restart = "always";
    serviceConfig.RestartSec = "30";
    after = ["startup.service"];
  };
  ##############################################################################
  
  ###### Defining the mounter script. This script mounts the external usb devices with correct permissions. ######
  environment.etc."nixos/mounter.sh" = { 
    source = ./mounter.sh;
    mode = "0774";
    group = "wheel";
  };
  ##############################################################################################################

}


