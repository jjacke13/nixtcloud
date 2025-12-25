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

  # Generate self-signed SSL certificate on first boot
  systemd.services.generate-ssl-cert = {
    description = "Generate self-signed SSL certificate for Nextcloud";
    wantedBy = [ "multi-user.target" ];
    before = [ "nginx.service" ];
    script = ''
      if [ ! -f ${sslCertDir}/cert.pem ]; then
        mkdir -p ${sslCertDir}
        ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:4096 \
          -keyout ${sslCertDir}/key.pem \
          -out ${sslCertDir}/cert.pem \
          -days 3650 -nodes \
          -subj "/CN=${name}.local" \
          -addext "subjectAltName=DNS:${name}.local,DNS:localhost,IP:127.0.0.1"
        chown nginx:nginx ${sslCertDir}/key.pem
        chown nginx:nginx ${sslCertDir}/cert.pem
        chmod 600 ${sslCertDir}/key.pem
        chmod 644 ${sslCertDir}/cert.pem
        echo "SSL certificate generated successfully"
      else
        echo "SSL certificate already exists"
      fi
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
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
  		    short_open_tag = "Off";
        };
  };

  # Configure Nextcloud nginx virtualHost for dual-port access
  # Port 80: HTTP for localhost (P2P tunnel access)
  # Port 443: HTTPS for nixtcloud.local (local network access)
  services.nginx.virtualHosts.nixtcloud = {
    listen = lib.mkForce [
      { addr = "0.0.0.0"; port = 80; ssl = false; }
      { addr = "0.0.0.0"; port = 443; ssl = true; }
    ];
    # Directly inject SSL certificate directives
    extraConfig = ''
      ssl_certificate ${sslCertDir}/cert.pem;
      ssl_certificate_key ${sslCertDir}/key.pem;
    '';
  };

}
