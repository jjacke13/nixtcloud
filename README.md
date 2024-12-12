# nixtcloud
Nextcloud with NixOS in the backend and P2P connectivity enabled

This implementation is based on the works of many amazing people. I just aim to provide a way to combine many things together and automate the installation of Nextcloud... even for users that do not know anything about Linux or NixOS. This system is built in a way to provide:

- Easy automated install of Nextcloud (no special linux/NixOS knowledge required)
- Minimal periodic maintenance
- Automated mounting of usb devices as nextcloud external storage (Currently FAT and ext4 formats supported, exfat and ntfs coming soon)
- very easy remote access to your Nextcloud, using the Holesail app in Android/iOS, Linux, Windows or MacOS just by scanning a qr code or copying a string.
- Privacy for everyone 

NixOS is used due to its nice feature that makes things declarative and makes the final system to require minimal periodic maintenance. The first version is available for Raspberry Pi 4, although it requires very few adjustments to work on different architecture (x86_64). The Nextcloud instance is available in the domain "nixtcloud.local" inside your Home network (assuming that you connect the pi to your router via ethernet). For remote P2P access, Holesail is used (also available in my repo: Holesail-nix), which is a nix package for the holesail.io nodejs program. You can use the connection string in 'remote.txt' file or scan the 'remote.jpg' Qr with the Holesail app in your phone. A big thanks to the guys at: holesail.io , Nextcloud, Nextcloud for Nix maintainers and of course those how contribute to Nix package manager and nixos repository. 

If I have seen further than others, it is by standing upon the shoulders of giants.

Privacy for everyone!

Build Instructions:

1. If your are runnning Nixos, just execute:
   
     $ nix build --system aarch64-linux github:jjacke13/nixtcloud#packages.aarch64-linux.sdcard
   
   Then decompress the resulting .zst image, burn it to an sd card, put the card in your Rpi 4, and enjoy! Assuming your Pi is connected to your home router with ethernet, you can visit " nixtcloud.local " inside your home network. Default 
   username and pass are: "admin" . Please change the password after your first connection.

3. If you are in other Linux or MacOS, you have to install the Nix package manager first.
   
     $ sh <(curl -L https://nixos.org/nix/install) --no-daemon

    Then run:
   
     $ nix build --extra-experimental-features nix-command --extra-experimental-features flakes --system aarch64-linux github:jjacke13/nixtcloud#packages.aarch64-linux.sdcard
   
   Then follow the rest steps of 1 above.

Once your are connected to your Nextcloud instance, you will find some files already there.

1. If you delete rebooter.txt , after some seconds the Pi will reboot.
2. The qr code in remote.jpg is the equivalent of remote.txt. You can use it to connect remotely to your Nextcloud using Holesail! You can find instructions for Holesail at holesail.io
3. In the Public folder you will find another string with its qr code. Whatever you put in public folder, you can share it with others just by giving them the string in "public.txt" for use in their Holesail. If they connect, the username and pass 
   are: "test" . There was no reason to put complex password here because it is a public folder after all...

If you accidentally delete remote.txt file or public.txt file, don't worry. Just delete the rebooter.txt file and upon reboot the system will create new connection strings.

If you connect a usb device on your Pi, wait 30 sec and then it will be available as Nextcloud external storage ;) You can connect multiple usb devices with an externally powered usb hub or a Pi usb hub hat. Just be carefull for the temperature...
  


*** This project is new and subject to changes without notification :P ***
