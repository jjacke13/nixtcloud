# nixtcloud
Nextcloud with NixOS in the backend and P2P connectivity enabled

This implementation is based on the works of many amazing people. I just aim to provide a way to combine many things together and automate the installation of Nextcloud... even for users that do not know anything about Linux or NixOS. This system is built in a way to provide:

- Easy automated install of Nextcloud (no special linux/NixOS knowledge required)
- Minimal periodic maintenance
- Automated mounting of usb devices as nextcloud external storage
- very easy remote access to your Nextcloud, using the Holesail app in Android/iOS, Linux, Windows or MacOS just by scanning a qr code or copying a string.
- Privacy for everyone 

NixOS is used due to its nice feature that makes things declarative and makes the final system to require minimal periodic maintenance. The first version is available for Raspberry Pi 4, although it requires very few adjustments to work on different architecture (x86_64). The Nextcloud instance is available in the domain "nixtcloud.local" inside your Home network (assuming that you connect the pi to your router via ethernet). For remote P2P access, Holesail is used (also available in my repo: Holesail-nix), which is a nix package for the holesail.io nodejs program. You can use the connection string in 'remote.txt' file or scan the 'remote.jpg' Qr with the Holesail app in your phone. A big thanks to the guys at: holesail.io , Nextcloud, Nextcloud for Nix maintainers and of course those how contribute to Nix package manager and nixos repository. 

If I have seen further than others, it is by standing upon the shoulders of giants.

Privacy for everyone!

P.S Very analytic instructions will be included very soon. Default username & pass: "admin"


*** This project is new and subject to changes without notification :P ***
