#!/bin/sh

CURPATH=$(pwd)
#/home/local/SPREADTRUM/gang.qie1/code/q_trunk/vendor/sprd/proprietories-source/packimage_scripts/signimage/firmware
CFGPATH=$CURPATH/../sprd/config
VDSP=$CURPATH/../../../../modules/vdsp/Cadence/xrp/xrp-firmware/faceid_fw.bin
VDSPSIGN=$CURPATH/../../../../modules/vdsp/Cadence/xrp/xrp-firmware/faceid_fw-sign.bin
export LD_LIBRARY_PATH=$CURPATH
doImgHeaderInsert()
{
    local NO_SECURE_BOOT=0
    local remove_orig_file_if_succeed=1
    local ret

    if [ -f $VDSP ] ; then
        $CURPATH/imgheaderinsert $VDSP $NO_SECURE_BOOT $remove_orig_file_if_succeed
        ret=$?
        if [ "$ret" = "1" ]; then
             echo "imgheaderinsert $VDSP NO_SECURE_BOOT=$NO_SECURE_BOOT remove_orig_file_if_succeed=$remove_orig_file_if_succeed failed!"
             return 1
        fi
	#echo "imgheaderinsert $VDSP NO_SECURE_BOOT=$NO_SECURE_BOOT remove_orig_file_if_succeed=$remove_orig_file_if_succeed successful"
    else
        echo "#### no $VDSP,please check ####"
	return 1
    fi

    return 0
}

doSignImage()
{
    #/*add sprd sign*/
    echo "doSignImage......"
    $CURPATH/sprd_sign  $VDSPSIGN  $CFGPATH  pss
}

doPackImage()
{
    echo "firmware doPackImage......"
    doImgHeaderInsert
    if [ "$?" = "1" ]; then
       echo "firmware doImgHeaderInsert error!!!"
       return 1
    fi
    doSignImage
}

doPackImage "$@"
