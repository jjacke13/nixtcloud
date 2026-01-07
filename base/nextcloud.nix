{ config, lib, pkgs, ... }:
let
    name = "nixtcloud";
    sslCertDir = "/var/lib/nixtcloud/ssl";
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
        package = pkgs.nextcloud32;
        hostName = name;
        database.createLocally = true;
        config = {
          dbtype = "sqlite";
          adminuser = "admin";
          adminpassFile = "/etc/nixos/adminpass.txt";
        };
        settings = {
          trusted_domains = [ "localhost" "${name}.local" "192.168.*.*" ];
          default_phone_region = "GR"; ### you can change this to your country code
          log_type = "file";
	        loglevel = 4;
	        maintenance_window_start = 1;
          quota_include_external_storage = true;
          overwriteprotocol = "https";
          overwritecondaddr = "^192\\.168\\..*$";
        };
        maxUploadSize = "5000M";
        appstoreEnable = true;
        autoUpdateApps.enable = true;
        extraAppsEnable = false; #we use Nextcloud's appstore
        configureRedis = true;
        caching.apcu = true;
        caching.redis = true;
        caching.memcached = false;
        phpOptions = {
  		    "opcache.interned_strings_buffer" = "10"; # Increase from default 8
        };
  };

  # Map to detect HTTPS based on port
  services.nginx.appendHttpConfig = ''
    map $server_port $fastcgi_https {
      default off;
      443 on;
    }
  '';

  # Configure Nextcloud nginx virtualHost for dual-port access
  # Port 80: HTTP for localhost (P2P tunnel access)
  # Port 443: HTTPS for nixtcloud.local (local network access)
  services.nginx.virtualHosts.nixtcloud = {
    listen = lib.mkForce [
      { addr = "0.0.0.0"; port = 80; ssl = false; }
      { addr = "0.0.0.0"; port = 443; ssl = true; }
    ];
    # Directly inject SSL certificate directives and HSTS header
    extraConfig = ''
      ssl_certificate ${sslCertDir}/cert.pem;
      ssl_certificate_key ${sslCertDir}/key.pem;
      add_header Strict-Transport-Security "max-age=15552000; includeSubDomains" always;
    '';
  };

  # HTTP to HTTPS redirect for nixtcloud.local only
  services.nginx.virtualHosts."${name}-redirect" = {
    serverName = "${name}.local";
    listen = [
      { addr = "0.0.0.0"; port = 80; ssl = false; }
    ];
    locations."/".return = "302 https://${name}.local$request_uri";
  };

}
