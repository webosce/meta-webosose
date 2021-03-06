# Imported from meta-raspberrypi with one modification to respect our
# KERNEL_IMAGE_SYMLINK_NAME, can be removed when upgrading to Yocto 2.6
# which will contain changes from:
# https://github.com/agherzan/meta-raspberrypi/pull/281

inherit image_types
inherit linux-raspberrypi-base

#
# Create an image that can be written onto a SD card using dd.
#
# The disk layout used is:
#
#    0                      -> IMAGE_ROOTFS_ALIGNMENT         - reserved for other data
#    IMAGE_ROOTFS_ALIGNMENT -> BOOT_SPACE                     - bootloader and kernel
#    BOOT_SPACE             -> SDIMG_SIZE                     - rootfs
#

#                                                     Default Free space = 1.3x
#                                                     Use IMAGE_OVERHEAD_FACTOR to add more space
#                                                     <--------->
#            4MiB              40MiB           SDIMG_ROOTFS
# <-----------------------> <----------> <---------------------->
#  ------------------------ ------------ ------------------------
# | IMAGE_ROOTFS_ALIGNMENT | BOOT_SPACE | ROOTFS_SIZE            |
#  ------------------------ ------------ ------------------------
# ^                        ^            ^                        ^
# |                        |            |                        |
# 0                      4MiB     4MiB + 40MiB       4MiB + 40Mib + SDIMG_ROOTFS

# This image depends on the rootfs image
IMAGE_TYPEDEP_rpi-sdimg = "${SDIMG_ROOTFS_TYPE}"

# Set kernel and boot loader
IMAGE_BOOTLOADER ?= "bcm2835-bootfiles"

# Set initramfs extension
KERNEL_INITRAMFS ?= ""

# Kernel image name
SDIMG_KERNELIMAGE_raspberrypi  ?= "kernel.img"
SDIMG_KERNELIMAGE_raspberrypi2 ?= "kernel7.img"
SDIMG_KERNELIMAGE_raspberrypi3-64 ?= "kernel8.img"

# Boot partition volume id
BOOTDD_VOLUME_ID ?= "${MACHINE}"

# Boot partition size [in KiB] (will be rounded up to IMAGE_ROOTFS_ALIGNMENT)
BOOT_SPACE ?= "40960"

# Set alignment to 4MB [in KiB]
IMAGE_ROOTFS_ALIGNMENT = "4096"

# Use an uncompressed ext3 by default as rootfs
SDIMG_ROOTFS_TYPE ?= "ext3"
SDIMG_ROOTFS = "${IMGDEPLOYDIR}/${IMAGE_NAME}.rootfs.${SDIMG_ROOTFS_TYPE}"

IMAGE_DEPENDS_rpi-sdimg = " \
    parted-native \
    mtools-native \
    dosfstools-native \
    virtual/kernel:do_deploy \
    ${IMAGE_BOOTLOADER} \
    ${@bb.utils.contains('RPI_USE_U_BOOT', '1', 'u-boot', '',d)} \
    ${@bb.utils.contains('RPI_USE_U_BOOT', '1', 'rpi-u-boot-scr', '',d)} \
"

# SD card image name
SDIMG = "${IMGDEPLOYDIR}/${IMAGE_NAME}.rootfs.rpi-sdimg"

# Compression method to apply to SDIMG after it has been created. Supported
# compression formats are "gzip", "bzip2" or "xz". The original .rpi-sdimg file
# is kept and a new compressed file is created if one of these compression
# formats is chosen. If SDIMG_COMPRESSION is set to any other value it is
# silently ignored.
#SDIMG_COMPRESSION ?= ""

# Additional files and/or directories to be copied into the vfat partition from the IMAGE_ROOTFS.
FATPAYLOAD ?= ""

# SD card vfat partition image name
SDIMG_VFAT_DEPLOY ?= "${RPI_USE_U_BOOT}"
SDIMG_VFAT = "${IMAGE_NAME}.vfat"
SDIMG_LINK_VFAT = "${IMGDEPLOYDIR}/${IMAGE_LINK_NAME}.vfat"

def split_overlays(d, out, ver=None):
    dts = d.getVar("KERNEL_DEVICETREE", True)
    # Device Tree Overlays are assumed to be suffixed by '-overlay.dtb' (4.1.x) or by '.dtbo' (4.4.9+) string and will be put in a dedicated folder
    if out:
        overlays = oe.utils.str_filter_out('\S+\-overlay\.dtb$', dts, d)
        overlays = oe.utils.str_filter_out('\S+\.dtbo$', overlays, d)
    else:
        overlays = oe.utils.str_filter('\S+\-overlay\.dtb$', dts, d) + \
                   " " + oe.utils.str_filter('\S+\.dtbo$', dts, d)

    return overlays

IMAGE_CMD_rpi-sdimg () {

    # Align partitions
    BOOT_SPACE_ALIGNED=$(expr ${BOOT_SPACE} + ${IMAGE_ROOTFS_ALIGNMENT} - 1)
    BOOT_SPACE_ALIGNED=$(expr ${BOOT_SPACE_ALIGNED} - ${BOOT_SPACE_ALIGNED} % ${IMAGE_ROOTFS_ALIGNMENT})
    SDIMG_SIZE=$(expr ${IMAGE_ROOTFS_ALIGNMENT} + ${BOOT_SPACE_ALIGNED} + $ROOTFS_SIZE)

    echo "Creating filesystem with Boot partition ${BOOT_SPACE_ALIGNED} KiB and RootFS $ROOTFS_SIZE KiB"

    # Check if we are building with device tree support
    DTS="${KERNEL_DEVICETREE}"

    # Initialize sdcard image file
    dd if=/dev/zero of=${SDIMG} bs=1024 count=0 seek=${SDIMG_SIZE}

    # Create partition table
    parted -s ${SDIMG} mklabel msdos
    # Create boot partition and mark it as bootable
    parted -s ${SDIMG} unit KiB mkpart primary fat32 ${IMAGE_ROOTFS_ALIGNMENT} $(expr ${BOOT_SPACE_ALIGNED} \+ ${IMAGE_ROOTFS_ALIGNMENT})
    parted -s ${SDIMG} set 1 boot on
    # Create rootfs partition to the end of disk
    parted -s ${SDIMG} -- unit KiB mkpart primary ext2 $(expr ${BOOT_SPACE_ALIGNED} \+ ${IMAGE_ROOTFS_ALIGNMENT}) -1s
    parted ${SDIMG} print

    # Create a vfat image with boot files
    BOOT_BLOCKS=$(LC_ALL=C parted -s ${SDIMG} unit b print | awk '/ 1 / { print substr($4, 1, length($4 -1)) / 512 /2 }')
    rm -f ${WORKDIR}/boot.img
    mkfs.vfat -n "${BOOTDD_VOLUME_ID}" -S 512 -C ${WORKDIR}/boot.img $BOOT_BLOCKS
    mcopy -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/bcm2835-bootfiles/* ::/
    if test -n "${DTS}"; then
        # Copy board device trees to root folder
        for dtbf in ${@split_overlays(d, True)}; do
            # WEBOS, respect our KERNEL_IMAGE_SYMLINK_NAME
            # In webOS we're using using following convention:
            # webos.inc:KERNEL_IMAGE_BASE_NAME = "$\{PREFERRED_PROVIDER_virtual/kernel}-$\{MACHINE}$\{WEBOS_KERNEL_IMAGE_BASE_NAME_PARTITION_SUFFIX}"
            # webos.inc:KERNEL_IMAGE_SYMLINK_NAME = "$\{KERNEL_IMAGE_BASE_NAME}$\{WEBOS_IMAGE_NAME_SUFFIX}"
            # While in default oe-core the naming is a lot simpler with just $\{MACHINE} in symlink:
            # kernel.bbclass:KERNEL_IMAGE_BASE_NAME ?= "$\{PKGE}-$\{PKGV}-$\{PKGR}-$\{MACHINE}-$\{DATETIME}"
            # kernel.bbclass:KERNEL_IMAGE_SYMLINK_NAME ?= "$\{MACHINE}"

            # kernel.bbclass is also using $\{KERNEL_IMAGETYPE_FOR_MAKE}"-"$\{KERNEL_IMAGE_SYMLINK_NAME}
            # as a base name for deployed files from $\{KERNEL_DEVICETREE}

            # But then meta-raspberrypi/classes/sdcard_image-rpi.bbclass doesn't respect this and
            # assumes that the default KERNEL_IMAGE_SYMLINK_NAME (MACHINE) was replaced by DTB_BASE_NAME in:
            # DTB_SYMLINK_NAME=`echo $\{symlink_name} | sed "s/$\{MACHINE}/$\{DTB_BASE_NAME}/g"`
            # so it uses only KERNEL_IMAGETYPE as a prefix:
            # $\{DEPLOY_DIR_IMAGE}/$\{KERNEL_IMAGETYPE}-$\{DTB_BASE_NAME}.dtb
            #            DTB_BASE_NAME=`basename $\{DTB} .dtb`
            #            mcopy -i $\{WORKDIR}/boot.img -s $\{DEPLOY_DIR_IMAGE}/$\{KERNEL_IMAGETYPE}-$\{DTB_BASE_NAME}.dtb ::$\{DTB_BASE_NAME}.dtb

            dtb_ext=${dtbf##*.}
            dtb_base_name=`basename $dtbf ."$dtb_ext"`
            for kernel_imagetype in ${KERNEL_IMAGETYPE}; do
                base_name=$kernel_imagetype"-"${KERNEL_IMAGE_BASE_NAME}
                dtb_name=`echo $base_name | sed "s/${MACHINE}/$dtb_base_name/g"`

                # We assume that there is only one item in KERNEL_IMAGETYPE_FOR_MAKE - Image
                # If there are more, then $dtb_base_name.dtb will be overwritten and last
                # type will win
                mcopy -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/$dtb_name.$dtb_ext ::$dtb_base_name.$dtb_ext
            done
        done

        # Copy device tree overlays to dedicated folder
        mmd -i ${WORKDIR}/boot.img overlays
        for dtbf in ${@split_overlays(d, False)}; do
            dtb_ext=${dtbf##*.}
            dtb_base_name=`basename $dtbf ."$dtb_ext"`
            for kernel_imagetype in ${KERNEL_IMAGETYPE}; do
                base_name=$kernel_imagetype"-"${KERNEL_IMAGE_BASE_NAME}
                dtb_name=`echo $base_name | sed "s/${MACHINE}/$dtb_base_name/g"`

                # We assume that there is only one item in KERNEL_IMAGETYPE_FOR_MAKE - Image
                # If there are more, then $dtb_base_name.dtb will be overwritten and last
                # type will win
                mcopy -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/$dtb_name.$dtb_ext ::overlays/$dtb_base_name.$dtb_ext
            done
        done
    fi
    if [ "${RPI_USE_U_BOOT}" = "1" ]; then
        mcopy -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/u-boot.bin ::${SDIMG_KERNELIMAGE}
        mcopy -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE}-${KERNEL_IMAGE_BASE_NAME}.bin ::${KERNEL_IMAGETYPE}
        mcopy -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/boot.scr ::boot.scr
    else
        mcopy -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE}-${KERNEL_IMAGE_BASE_NAME}.bin ::${SDIMG_KERNELIMAGE}
    fi

    if [ -n ${FATPAYLOAD} ] ; then
        echo "Copying payload into VFAT"
        for entry in ${FATPAYLOAD} ; do
            # add the || true to stop aborting on vfat issues like not supporting .~lock files
            mcopy -i ${WORKDIR}/boot.img -s -v ${IMAGE_ROOTFS}$entry :: || true
        done
    fi

    # Add stamp file
    echo "${IMAGE_NAME}" > ${WORKDIR}/image-version-info
    mcopy -i ${WORKDIR}/boot.img -v ${WORKDIR}/image-version-info ::

    # Deploy vfat partition
    if [ "${SDIMG_VFAT_DEPLOY}" = "1" ]; then
        cp ${WORKDIR}/boot.img ${IMGDEPLOYDIR}/${SDIMG_VFAT}
        ln -sf ${SDIMG_VFAT} ${SDIMG_LINK_VFAT}
    fi

    # Burn Partitions
    dd if=${WORKDIR}/boot.img of=${SDIMG} conv=notrunc seek=1 bs=$(expr ${IMAGE_ROOTFS_ALIGNMENT} \* 1024)
    # If SDIMG_ROOTFS_TYPE is a .xz file use xzcat
    if echo "${SDIMG_ROOTFS_TYPE}" | egrep -q "*\.xz"
    then
        xzcat ${SDIMG_ROOTFS} | dd of=${SDIMG} conv=notrunc seek=1 bs=$(expr 1024 \* ${BOOT_SPACE_ALIGNED} + ${IMAGE_ROOTFS_ALIGNMENT} \* 1024)
    else
        dd if=${SDIMG_ROOTFS} of=${SDIMG} conv=notrunc seek=1 bs=$(expr 1024 \* ${BOOT_SPACE_ALIGNED} + ${IMAGE_ROOTFS_ALIGNMENT} \* 1024)
    fi

    # Optionally apply compression
    case "${SDIMG_COMPRESSION}" in
    "gzip")
        gzip -k9 "${SDIMG}"
        ;;
    "bzip2")
        bzip2 -k9 "${SDIMG}"
        ;;
    "xz")
        xz -k "${SDIMG}"
        ;;
    esac
}

ROOTFS_POSTPROCESS_COMMAND += " rpi_generate_sysctl_config ; "

rpi_generate_sysctl_config() {
    # systemd sysctl config
    test -d ${IMAGE_ROOTFS}${sysconfdir}/sysctl.d && \
        echo "vm.min_free_kbytes = 8192" > ${IMAGE_ROOTFS}${sysconfdir}/sysctl.d/rpi-vm.conf

    # sysv sysctl config
    IMAGE_SYSCTL_CONF="${IMAGE_ROOTFS}${sysconfdir}/sysctl.conf"
    test -e ${IMAGE_ROOTFS}${sysconfdir}/sysctl.conf && \
        sed -e "/vm.min_free_kbytes/d" -i ${IMAGE_SYSCTL_CONF}
    echo "" >> ${IMAGE_SYSCTL_CONF} && echo "vm.min_free_kbytes = 8192" >> ${IMAGE_SYSCTL_CONF}
}
