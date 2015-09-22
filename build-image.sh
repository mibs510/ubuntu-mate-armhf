#!/usr/bin/env bash

########################################################################
#
# Copyright (C) 2015 Ryan Finnie <ryan@finnie.org>
# Copyright (C) 2015 Rohith Madhavan <rohithmadhavan@gmail.com>
# Copyright (C) 2015 Martin Wimpress <code@ubuntu-mate.org>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
########################################################################

set -ex

RELEASE=vivid
BASEDIR=/var/local/build/${RELEASE}
BUILDDIR=${BASEDIR}/ubuntu-mate
MATE_R=${BUILDDIR}/mate
MATE_R=${BUILDDIR}/odroidc1
export TZ=UTC

if [ $(id -u) -ne 0 ]; then
    echo "ERROR! Must be root."
    exit 1
fi

# Don't clobber an old build
if [ -d "${BUILDDIR}" ]; then
  echo "WARNING! ${BUILDDIR} exists. Press any key to continue or CTRL + C to exit."
  read
fi

# Mount host system
function mount_system() {
    mount -t proc none $R/proc
    mount -t sysfs none $R/sys
    mount -o bind /dev $R/dev
    mount -o bind /dev/pts $R/dev/pts
}

# Unmount host system
function umount_system() {
    umount -f $R/dev/pts
    umount -f $R/proc
    umount -f $R/sys
    umount -r $R/dev
}

function apt_upgrade() {
    chroot $R apt-get update
    chroot $R apt-get -y -u dist-upgrade
}

function apt_clean() {
    # Clean cached downloads
    chroot $R apt-get clean
}

function configure_odroidc1() {
    local FS="${1}"
    if [ "${FS}" != "ext4" ] && [ "${FS}" != 'f2fs' ]; then
        echo "ERROR! Unsupport filesystem requested. Exitting."
        exit 1
    fi

    echo "deb http://deb.odroid.in/c1/ trusty main" >  $R/etc/apt/sources.d/odroid.list
    echo "deb http://deb.odroid.in/ trusty main"    >> $R/etc/apt/sources.d/odroid.list

}
function configure_raspi2() {
    local FS="${1}"
    if [ "${FS}" != "ext4" ] && [ "${FS}" != 'f2fs' ]; then
        echo "ERROR! Unsupport filesystem requested. Exitting."
        exit 1
    fi

    local OMX="http://omxplayer.sconde.net/builds/omxplayer_0.3.6~git20150402~74aac37_armhf.deb"

    # Install the RPi PPA
    cat <<"EOM" >$R/etc/apt/preferences.d/rpi2-ppa
Package: *
Pin: release o=LP-PPA-fo0bar-rpi2
Pin-Priority: 990

Package: *
Pin: release o=LP-PPA-fo0bar-rpi2-staging
Pin-Priority: 990
EOM

    # Install the RPi PPA
    chroot $R apt-add-repository -y ppa:fo0bar/rpi2
    chroot $R apt-get update
    chroot $R apt-get -y install rpi2-ubuntu-errata

    # Kernel installation
    # Install flash-kernel last so it doesn't try (and fail) to detect the
    # platform in the chroot.
    chroot $R apt-get -y install raspberrypi-bootloader-nokernel
    chroot $R apt-get -y --no-install-recommends install linux-image-rpi2
    chroot $R apt-get -y install flash-kernel
    VMLINUZ="$(ls -1 $R/boot/vmlinuz-* | sort | tail -n 1)"
    [ -z "$VMLINUZ" ] && exit 1
    cp $VMLINUZ $R/boot/firmware/kernel7.img
    INITRD="$(ls -1 $R/boot/initrd.img-* | sort | tail -n 1)"
    [ -z "$INITRD" ] && exit 1
    cp $INITRD $R/boot/firmware/initrd7.img

    # Install video drivers
    chroot $R apt-get -y install libraspberrypi0 libraspberrypi-bin \
    libraspberrypi-bin-nonfree

    chroot $R apt-get -y install xserver-xorg-video-fbturbo
    cat <<EOM >$R/etc/X11/xorg.conf
Section "Device"
    Identifier "Raspberry Pi FBDEV"
    Driver "fbturbo"
    Option "fbdev" "/dev/fb0"
    Option "SwapbuffersWait" "true"
EndSection
EOM

    # Create sym-links to VideoCore utilities for 3rd party script
    # compatibility.
    mkdir -p ${R}/opt/vc/{bin,sbin}
    for FILE in containers_check_frame_int \
                containers_datagram_receiver \
                containers_datagram_sender \
                containers_dump_pktfile \
                containers_rtp_decoder \
                containers_stream_client \
                containers_stream_server \
                containers_test \
                containers_test_bits \
                containers_test_uri \
                containers_uri_pipe \
                edidparser \
                mmal_vc_diag \
                raspistill \
                raspivid \
                raspividyuv \
                raspiyuv \
                tvservice \
                vcdbg \
                vcgencmd \
                vchiq_test \
                vcsmem; do
        chroot $R ln -s /usr/bin/${FILE} /opt/vc/bin/
    done
    chroot $R ln -s /usr/sbin/vcfiled /opt/vc/sbin/

    # omxplayer
    # - Requires: libpcre3 libfreetype6 fonts-freefont-ttf dbus libssl1.0.0 libsmbclient libssh-4
    wget -c "${OMX}" -O $R/tmp/omxplayer.deb
    chroot $R gdebi -n /tmp/omxplayer.deb

    # copies-and-fills
    wget -c http://archive.raspberrypi.org/debian/pool/main/r/raspi-copies-and-fills/raspi-copies-and-fills_0.4-1_armhf.deb -O $R/tmp/cofi.deb
    chroot $R gdebi -n /tmp/cofi.deb

    # raspi-config - Needs forking/modifying to support Ubuntu 15.04
    # - Requires: whiptail parted lua5.1 triggerhappy
    #wget -c http://archive.raspberrypi.org/debian/pool/main/r/raspi-config/raspi-config_20150131-1_all.deb -O $R/tmp/rasp-config.deb
    #chroot $R gdebi -n /tmp/rasp-config.deb

    # Set up fstab
    cat <<EOM >$R/etc/fstab
proc            /proc           proc    defaults          0       0
/dev/mmcblk0p2  /               ${FS}   defaults,noatime  0       1
/dev/mmcblk0p1  /boot/firmware  vfat    defaults          0       2
EOM

    # Set up firmware config
    cat <<EOM >$R/boot/firmware/config.txt
# For more options and information see
# http://www.raspberrypi.org/documentation/configuration/config-txt.md
# Some settings may impact device functionality. See link above for details

# uncomment if you get no picture on HDMI for a default "safe" mode
#hdmi_safe=1

# uncomment this if your display has a black border of unused pixels visible
# and your display can output without overscan
#disable_overscan=1

# uncomment the following to adjust overscan. Use positive numbers if console
# goes off screen, and negative if there is too much border
#overscan_left=16
#overscan_right=16
#overscan_top=16
#overscan_bottom=16

# uncomment to force a console size. By default it will be display's size minus
# overscan.
#framebuffer_width=1280
#framebuffer_height=720

# uncomment if hdmi display is not detected and composite is being output
#hdmi_force_hotplug=1

# uncomment to force a specific HDMI mode (this will force VGA)
#hdmi_group=1
#hdmi_mode=1

# uncomment to force a HDMI mode rather than DVI. This can make audio work in
# DMT (computer monitor) modes
#hdmi_drive=2

# uncomment to increase signal to HDMI, if you have interference, blanking, or
# no display
#config_hdmi_boost=4

# uncomment for composite PAL
#sdtv_mode=2

#uncomment to overclock the arm. 700 MHz is the default.
#arm_freq=800
EOM

    ln -sf firmware/config.txt $R/boot/config.txt
    echo 'dwc_otg.lpm_enable=0 console=tty1 root=/dev/mmcblk0p2 elevator=deadline rootwait' > $R/boot/firmware/cmdline.txt
    ln -sf firmware/cmdline.txt $R/boot/cmdline.txt

    # Load sound module on boot
    cat <<EOM >$R/lib/modules-load.d/rpi2.conf
snd_bcm2835
bcm2708_rng
EOM

# Blacklist platform modules not applicable to the RPi2
    cat <<EOM >$R/etc/modprobe.d/rpi2.conf
blacklist snd_soc_pcm512x_i2c
blacklist snd_soc_pcm512x
blacklist snd_soc_tas5713
blacklist snd_soc_wm8804
EOM
}

function clean_up() {
    rm -f $R/etc/apt/sources.list.save
    rm -f $R/etc/resolvconf/resolv.conf.d/original
    rm -rf $R/run
    mkdir -p $R/run/resolvconf
    rm -f $R/etc/*-
    rm -rf $R/tmp/*
    rm -f $R/var/crash/*
    rm -f $R/var/lib/urandom/random-seed

    # Potentially sensitive.
    rm -f $R/root/.bash_history
    rm -f $R/root/.ssh/known_hosts

    # Machine-specific, so remove in case this system is going to be
    # cloned.  These will be regenerated on the first boot.
    rm -f $R/etc/udev/rules.d/70-persistent-cd.rules
    rm -f $R/etc/udev/rules.d/70-persistent-net.rules
    [ -L $R/var/lib/dbus/machine-id ] || rm -f $R/var/lib/dbus/machine-id
    rm -f $R/etc/machine-id
}

function make_image() {
    # Build the image file
    local FS="${1}"
    local GB=${2}
    local DEVICE_NAME="${3}"

    IMAGE="ubuntu-mate-15.04-desktop-${DEVICE_NAME}.img"

    if [ "${FS}" != "ext4" ] && [ "${FS}" != 'f2fs' ]; then
        echo "ERROR! Unsupport filesystem requested. Exitting."
        exit 1
    fi

    if [ ${GB} -ne 4 ] && [ ${GB} -ne 8 ]; then
        echo "ERROR! Unsupport card image size requested. Exitting."
        exit 1
    fi

    if [ ${GB} -eq 4 ]; then
        SEEK=3750
        SIZE=7546880
        SIZE_LIMIT=3685
    elif [ ${GB} -eq 8 ]; then
        SEEK=7680
        SIZE=15728639
        SIZE_LIMIT=7615
    fi

    dd if=/dev/zero of="${BASEDIR}/${IMAGE}" bs=1M count=1
    dd if=/dev/zero of="${BASEDIR}/${IMAGE}" bs=1M count=0 seek=${SEEK}

    sfdisk -f "$BASEDIR/${IMAGE}" <<EOM
unit: sectors

1 : start=     2048, size=   131072, Id= c, bootable
2 : start=   133120, size=  ${SIZE}, Id=83
3 : start=        0, size=        0, Id= 0
4 : start=        0, size=        0, Id= 0
EOM

    BOOT_LOOP="$(losetup -o 1M --sizelimit 64M -f --show ${BASEDIR}/${IMAGE})"
    ROOT_LOOP="$(losetup -o 65M --sizelimit ${SIZE_LIMIT}M -f --show ${BASEDIR}/${IMAGE})"
    mkfs.vfat -n BOOT -S 512 -s 16 -v "${BOOT_LOOP}"
    if [ "${FS}" == "ext4" ]; then
        mkfs.ext4 -L ROOT -m 0 "${ROOT_LOOP}"
    else
        mkfs.f2fs -l ROOT -o 1 "${ROOT_LOOP}"
    fi

    #################################################################
    # NOTE! - This may need adapting for different devices.         #
    # This is currently based on what the Raspberry Pi 2 requires.  #
    #################################################################
    MOUNTDIR="${BUILDDIR}/mount"
    mkdir -p "${MOUNTDIR}"
    mount "${ROOT_LOOP}" "${MOUNTDIR}"
    mkdir -p "${MOUNTDIR}/boot/firmware"
    mount "${BOOT_LOOP}" "${MOUNTDIR}/boot/firmware"
    rsync -a --progress "$R/" "${MOUNTDIR}/"
    umount "${MOUNTDIR}/boot/firmware"
    umount "${MOUNTDIR}"
    losetup -d "${ROOT_LOOP}"
    losetup -d "${BOOT_LOOP}"
}

function armhf_image() {
    R=${MATE_R}
    local FS="${1}"
    local GB="${2}"
    local DEVICE_NAME="${3}"

    if [ "${FS}" != "ext4" ] && [ "${FS}" != 'f2fs' ]; then
        echo "ERROR! Unsupport filesystem requested. Exitting."
        exit 1
    fi

    if [ ${GB} -ne 4 ] && [ ${GB} -ne 8 ]; then
        echo "ERROR! Unsupport card image size requested. Exitting."
        exit 1
    fi

    mount_system
    if [ "${DEVICE_NAME}" == "raspi2"
        configure_raspi2 ${FS}
    elif [ "${DEVICE_NAME}" == "odroidc1"
        configure_odroidc1 ${FS}
    else
        echo "ERROR! Unknown device - ${DEVICE_NAME}. Exitting."
        umount_system
        exit 1
    fi
    apt_clean
    clean_up
    umount_system
    make_image ${FS} ${GB} ${DEVICE_NAME}
}

# File systems can be 'ext4' or 'f2fs'
# Size can be '4' or '8'
# The device name is arbitary but will need adding to the armhf_image() function.
armhf_image ext4 4 odroidc1
