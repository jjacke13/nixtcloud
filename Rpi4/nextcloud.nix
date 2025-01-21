{ config, lib, pkgs, ... }:
let
    name = "nixtcloud";
in
{
  #### Defining the admin password file. This file is used to set the admin password for the nextcloud instance. ####
  environment.etc."nixos/adminpass.txt" = { 
    text = ''admin'';
    mode = "0644";
    group = "wheel";
  };

  services.nextcloud = {
        package = pkgs.nextcloud30;
        enable = true;
        hostName = name;
        database.createLocally = true;
        config.dbtype = "pgsql";
        config.adminuser = "admin";
        config.adminpassFile = "/etc/nixos/adminpass.txt";
        settings.trusted_domains = [ "${name}.local" ];
        settings.default_phone_region = "GR"; ### you can change this to your country code
        settings.log_type = "file";
	settings.loglevel = 4;
	maxUploadSize = "5000M";
        appstoreEnable = true;
        extraAppsEnable = true;
        configureRedis = true;
        caching.apcu = true;
        caching.redis = true;
        caching.memcached = true;
        settings.nginx.recommendedHttpHeaders =  true;
	settings.nginx.hstsMaxAge = 15553000000;
	settings = { maintenance_window_start = 1;};
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
