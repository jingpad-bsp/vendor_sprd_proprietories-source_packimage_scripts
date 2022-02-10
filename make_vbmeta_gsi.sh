#!/bin/bash
CURPATH=$(pwd)
HOST_OUT=$(get_build_var HOST_OUT_EXECUTABLES)
PRODUCT_OUT_PATH=$(get_build_var PRODUCT_OUT)
CFGPATH=$CURPATH/vendor/sprd/proprietories-source/packimage_scripts/signimage/sprd/config
VBMETA_KEY=$CFGPATH/rsa4096_vbmeta.pem
VER_CONFIG=$CFGPATH/version.cfg
IMG_HEADER=$HOST_OUT/imgheaderinsert
AVB_TOOL=$HOST_OUT/avbtool
VBMETA=vbmeta.img

getRollbackIndex()
{
    rollback_index=0
    name=avb_version_$1
    rollback_index=`sed -n '/'$name'/p'  $VER_CONFIG | sed -n 's/'$name'=//gp'`
}
AvbMakeVbmetaGSI()
{
    echo "Make vbmeta gsi......"
    getRollbackIndex vbmeta
    echo "rollback_index = $rollback_index"
    $AVB_TOOL make_vbmeta_image --chain_partition boot:1:$CFGPATH/rsa4096_boot_pub.bin \
                                --chain_partition dtbo:10:$CFGPATH/rsa4096_boot_pub.bin \
                                --chain_partition recovery:2:$CFGPATH/rsa4096_recovery_pub.bin \
                                --chain_partition vbmeta_system:3:$CFGPATH/rsa4096_system_pub.bin \
                                --chain_partition vbmeta_vendor:4:$CFGPATH/rsa4096_vendor_pub.bin \
                                $(get_build_var BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS) \
                                --key $VBMETA_KEY \
                                --algorithm SHA256_RSA4096 \
                                --padding_size 4096 \
                                --set_verification_disabled_flag \
                                --rollback_index $rollback_index \
                                --output $VBMETA
    $IMG_HEADER $VBMETA 1 1
    mv vbmeta-sign.img vbmeta-gsi.img
    cp vbmeta-gsi.img $PRODUCT_OUT_PATH/
    echo "Make vbmeta gsi done."
}
# ************* #
# main function #
# ************* #
echo "make vbmeta-gsi.img script, version 1.0"
AvbMakeVbmetaGSI
