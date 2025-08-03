# NixtCloud - Simple Installation Guide

**Your Personal Cloud Made Easy!**

NixtCloud gives you your own private cloud storage (like Google Drive or Dropbox) that runs on a Raspberry Pi in your home. Access your files from anywhere, with complete privacy and control.

## What You'll Need

- Raspberry Pi 4 or 5
- MicroSD card (32GB or larger recommended)
- Computer with internet connection
- Ethernet cable to connect Pi to your router

## Step-by-Step Installation

### 1. Download the Image
- Go to the [Releases page](https://github.com/jjacke13/nixtcloud/releases)
- Download the latest `.zst` file (compressed image)

### 2. Extract the Image
- **Windows**: Use [7-Zip](https://www.7-zip.org/) to extract the `.zst` file
- **Mac**: Use [The Unarchiver](https://theunarchiver.com/) or similar
- **Linux**: Use the command `unzstd filename.zst`

### 3. Flash to SD Card
- Download [Balena Etcher](https://etcher.balena.io/) (recommended for Windows users)
- Insert your microSD card into your computer
- Open Balena Etcher
- Select the extracted image file
- Select your SD card
- Click "Flash"

### 4. Setup Your Pi
- Insert the SD card into your Raspberry Pi
- Connect Pi to your router with ethernet cable
- Power on your Pi
- Wait 2-3 minutes for initial setup

### 5. Access Your Cloud
- Open any web browser on a device connected to your home network
- Go to: `nixtcloud.local`
- Login with:
  - **Username**: `admin`
  - **Password**: `admin`
- **⚠️ Important**: Change your password immediately after first login!

## Features

✅ **Automatic USB Storage**: Plug in USB drives and they'll appear as external storage in 30 seconds

✅ **Remote Access**: Use the Holesail app on your phone to access files from anywhere

✅ **File Sharing**: Share files with others using the public folder

✅ **Privacy First**: Your data stays on your device, not on someone else's server

## Getting Remote Access

1. In your Nextcloud, look for the file `remote.jpg`
2. Download the [Holesail app](https://holesail.io) on your phone
3. Scan the QR code in `remote.jpg` with the Holesail app
4. Access your files from anywhere!

## Need Help?

- If something goes wrong, delete the `rebooter.txt` file in your Nextcloud to restart the Pi
- If you lose your remote access codes, restart the Pi (they'll be recreated)
- Make sure your Pi is connected to your router with an ethernet cable

---

**That's it! You now have your own private cloud running at home.**

*Privacy for everyone!*