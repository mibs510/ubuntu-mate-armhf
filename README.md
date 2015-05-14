<!-- 
.. title: Ubuntu MATE generic armhf rootfs
.. slug: armhf-rootfs
.. date: 2015-05-09 13:01:09 UTC
.. tags: Ubuntu,MATE,armhf
.. link: 
.. description: Ubuntu MATE 15.04 generic armhf root file system
.. type: text
.. author: Martin Wimpress
-->

The Ubuntu MATE team have made an Ubuntu MATE 15.04 root file system image for 
ARMv7 devices. This root file system is intended for ARMv7 enthusiasts and 
board manufacturers who'd like to make an Ubuntu MATE image for their device. 
In order to adapt the root file system for your device you'll need to:

  * Add a boot loader
  * Add a kernel
  * Add X.org 1.17 drivers
  * Add any other hardware specific configuration
  
If we start seeing new Ubuntu MATE device images created by the community the
Ubuntu MATE project will gladly host the images and create a page to catalogue 
all the available images. 

The root file system is based on the regular Ubuntu `armhf` base, and not the
new Snappy Core, which means that the installation procedure for applications is
the same as that for the regular desktop version, ie using `apt-get`. 

**NOTE! There are no predefined user accounts**. The first time you boot the
Ubuntu MATE image it will run through a setup wizard where you can create your
own user account and configure your regional settings.

## Making an Ubuntu MATE ARMv7 device image

These instructions are brief but hopefully sufficient for ARM device hackers to
get started.

### Download

The generic Ubuntu MATE armhf root filesystem tarball is available for download.

  * http://master.dl.sourceforge.net/project/ubuntu-mate/15.04/armhf/ubuntu-mate-15.04-desktop-armhf-rootfs.tar.gz
      
### Extract the root file system

The root filesystem tarball will require a minimum of 4GB to extract. Extract
the rootfs archive to the location the example build script uses.

    sudo mkdir -p /var/local/build/vivid/ubuntu-mate/mate
    cd /var/local/build/vivid/ubuntu-mate/mate
    tar xvf ~/Download/ubuntu-mate-15.04-desktop-armhf-rootfs.tar.gz .

### Get the example build script

**NOTE!** Currently this script will only run on an `armhf` device.

The Ubuntu MATE team have created a very simple script that builds an Ubuntu
MATE armhf image. This is largely based on the image we made for the Raspberry
Pi 2 and will require some modification for other devices.

    cd ~
    git clone git@bitbucket.org:ubuntu-mate/ubuntu-mate-armhf.git

### Build an image

**NOTE!** Currently this script will only run on an `armhf` device.

In order to add support for a new ARMv7 device you will need to:

  * Create a `configure_device()` function. The `configure_raspi2()` can be used
  as a reference.
  * Modify the `armhf_image()` function so `${DEVICE_NAME}` can call your
  `configure_device()` function.
  * You may need to modify the `make_image()` function to correctly setup the
  `/boot` and `/` partitions for your device.
  * At the bottom of the script add a call to `armhf_image` that references your
  device.

Once the above changes have been made, execute the script from a shell.

    sudo ./build-image.sh

This will take a long time, so I suggest you start this running before you go
to bed. 

**Tip!** Mount `/var/local/build/` on a NAS via NFS.

If you add support for a new device please submit a pull request.

  * <https://bitbucket.org/ubuntu-mate/ubuntu-mate-armhf>

### Write an image to flash

Once you've created an image it can be written to flash storage using `ddrescue`.

    sudo ddrescue -d -D --force ubuntu-mate-15.04-desktop-armhf-device.img /dev/sdX

The flash storage may be mounted on any `/dev/sdX` so use the command `lsblk` to
check.

## Feedback and Improvements

If you start working on, or create, an Ubuntu MATE image for an ARMv7 device then
please let us know in the [Ubuntu MATE Development Discussion](https://ubuntu-mate.community/c/development-discussion) forum.

If you have any improvements, or add new device support, then please submit a
pull request to our BitBucket.

  * <https://bitbucket.org/ubuntu-mate/ubuntu-mate-armhf>

## References

The Ubuntu MATE team have created an image for the Raspberry Pi 2. It may be a
useful reference.

  * <https://bitbucket.org/ubuntu-mate/ubuntu-mate-rpi2>

## Changes

### 2015-05-09

  * Initial Release.
