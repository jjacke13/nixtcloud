{ config, lib, pkgs, ... }:

{

services.nextcloud = {
        package = pkgs.nextcloud30;
        enable = true;
        hostName = "nixtcloud";
        database.createLocally = true;
        config.dbtype = "pgsql";
        services.nextcloud.config.adminuser = "admin";
        config.adminpassFile = "/etc/nixos/dbpass.txt";
        settings.trusted_domains = [ "nixtcloud.local"];
        settings.default_phone_region = "US";
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
