{ config, lib, pkgs, ... }:

{
  #### First boot initialization - runs only once ####
  systemd.services.first-boot = {
    description = "First boot initialization";
    wantedBy = [ "multi-user.target" ];
    after = ["network.target" "nextcloud-setup.service"];
    before = ["startup.service" "nginx.service"];
    unitConfig.ConditionPathExists = "!/var/lib/first-boot-done";
    path = [ pkgs.coreutils pkgs.openssl ];
    script = ''
          # Generate SSL certificate for nixtcloud.local only
          mkdir -p /var/lib/nixtcloud/ssl
          ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:4096 \
            -keyout /var/lib/nixtcloud/ssl/key.pem \
            -out /var/lib/nixtcloud/ssl/cert.pem \
            -days 3650 -nodes \
            -subj "/CN=nixtcloud.local" \
            -addext "subjectAltName=DNS:nixtcloud.local"
          chown nginx:nginx /var/lib/nixtcloud/ssl/key.pem
          chown nginx:nginx /var/lib/nixtcloud/ssl/cert.pem
          chmod 600 /var/lib/nixtcloud/ssl/key.pem
          chmod 644 /var/lib/nixtcloud/ssl/cert.pem

          # Enable/disable Nextcloud apps
          /run/current-system/sw/bin/nextcloud-occ app:enable files_external
          /run/current-system/sw/bin/nextcloud-occ app:enable contacts
          /run/current-system/sw/bin/nextcloud-occ app:enable calendar
          /run/current-system/sw/bin/nextcloud-occ app:enable notes
          /run/current-system/sw/bin/nextcloud-occ app:disable photos
          /run/current-system/sw/bin/nextcloud-occ app:disable files_trashbin
          /run/current-system/sw/bin/nextcloud-occ app:disable nextbackup
          /run/current-system/sw/bin/nextcloud-occ app:disable app_api
          /run/current-system/sw/bin/nextcloud-occ app:disable federation
          /run/current-system/sw/bin/nextcloud-occ app:disable nextcloud_announcements
          /run/current-system/sw/bin/nextcloud-occ app:disable updatenotification
          /run/current-system/sw/bin/nextcloud-occ app:disable survey_client


          # Create Public folder
          mkdir -p /mnt/Public
          chown -R nextcloud:nextcloud /mnt/Public

          # Mark first boot as complete
          touch /var/lib/first-boot-done
    '';
    serviceConfig.Type = "oneshot";
  };
}
