{ config, lib, pkgs, ... }:
let
    name = "test";
in
{
  #### Defining the admin password file. This file is used to set the admin password for the nextcloud instance. ####
  environment.etc."nixos/adminpass.txt" = { 
    text = ''admin'';
    mode = "0644";
    group = "wheel";
  };

  services.nextcloud = {
        enable = true;
        package = pkgs.nextcloud30;
        hostName = name;
        database.createLocally = true;
        config = {
                dbtype = "pgsql";
                adminuser = "admin";
                adminpassFile = "/etc/nixos/adminpass.txt";
        };
        settings = {
                trusted_domains = [ "${name}.local" ];
                default_phone_region = "GR"; ### you can change this to your country code
                log_type = "file";
	        loglevel = 4;
	        nginx.recommendedHttpHeaders =  true;
	        nginx.hstsMaxAge = 15553000000;
	        maintenance_window_start = 1;
        };
        maxUploadSize = "5000M";
        appstoreEnable = true;
        extraAppsEnable = true;
        configureRedis = true;
        caching.apcu = true;
        caching.redis = true;
        caching.memcached = false;
        phpOptions = {  		
                "opcache.fast_shutdown" = "1";
  		          "opcache.interned_strings_buffer" = "10";
  		          "opcache.max_accelerated_files" = "10000";
  		          "opcache.memory_consumption" = "128";
  		          "opcache.revalidate_freq" = "1";
  		          output_buffering = "0";
  		          short_open_tag = "Off"; };
  };
  
}
