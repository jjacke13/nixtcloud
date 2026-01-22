{ config, lib, pkgs, ... }:

let
  oc = "/run/current-system/sw/bin/nextcloud-occ";
in
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
          ${oc} app:enable files_external
          ${oc} app:enable contacts
          ${oc} app:enable calendar
          ${oc} app:enable notes
          ${oc} app:disable photos
          ${oc} app:disable files_trashbin
          ${oc} app:disable nextbackup
          ${oc} app:disable app_api
          ${oc} app:disable federation
          ${oc} app:disable nextcloud_announcements
          ${oc} app:disable updatenotification
          ${oc} app:disable survey_client

          # Create disabled-storage group (for hiding unplugged USB drives)
          ${oc} group:add disabled-storage

          cat > /var/lib/nextcloud/usb_storage_map.txt <<'EOF'
# USB Storage Mapping Database
# Format: UUID|mount_id|mount_path|label
# This file maps USB partition UUIDs to Nextcloud external storage entries
EOF
          chown nextcloud:nextcloud /var/lib/nextcloud/usb_storage_map.txt
          chmod 644 /var/lib/nextcloud/usb_storage_map.txt

          # Create Public folder
          mkdir -p /mnt/Public
          chown -R nextcloud:nextcloud /mnt/Public
          ${oc} files_external:create "/Public" local null::null -c datadir="/mnt/Public"

          # Mark first boot as complete
          touch /var/lib/first-boot-done
    '';
    serviceConfig.Type = "oneshot";
  };
}
