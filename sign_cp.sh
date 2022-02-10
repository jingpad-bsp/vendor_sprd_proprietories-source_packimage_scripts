#!/bin/bash
#
# Author: bill.ji@spreadtrum.com
#
# secureboot sign tool
#
# Need environment
# bash
# awk
#
# **************** #
# input parameters #
# **************** #
TOPDIR=$1
SECBOOT=$2
# *************** #
# var declaration #
# *************** #
IMG_DIR=$(get_build_var PRODUCT_OUT)
CURPATH=$TOPDIR/vendor/sprd/proprietories-source/packimage_scripts
CFGPATH=$CURPATH/signimage/sprd/config/
PAC_PY=$TOPDIR/vendor/sprd/release/pac_script/parser_ini.py
PRODUCT=$(get_build_var TARGET_PRODUCT)
BUILD_VARIANT=$(get_build_var TARGET_BUILD_VARIANT)
BUILD_VER=$(get_build_var TARGET_BUILD_VERSION)
PROJECT=$PRODUCT-$TARGET_BUILD_VARIANT-$BUILD_VER
BOARD=$(get_build_var TARGET_BOARD)
OUTDIR=$TOPDIR/$IMG_DIR/cp_sign
ChipType=""
# configs
MB=1048576
VBMETA_KEY=$CFGPATH/rsa4096_vbmeta.pem
MODEM_KEY=$CFGPATH/rsa4096_modem.pem
VER_CONFIG=$CFGPATH/version.cfg
PAC_CONFILE=$TOPDIR/$IMG_DIR/$BOARD.xml
# sign tools
HOSTPATH=$(get_build_var HOST_OUT_EXECUTABLES)
IMG_HEADER=$HOSTPATH/imgheaderinsert
SPRD_SIGN=$HOSTPATH/sprd_sign
SPLIT_TOOL=$HOSTPATH/splitimg
AVB_TOOL=$HOSTPATH/avbtool
# images
SPL=$IMG_DIR/u-boot-spl-16k.bin
SPLSIGN=$IMG_DIR/u-boot-spl-16k-sign.bin
SML=$IMG_DIR/sml.bin
SMLSIGN=$IMG_DIR/sml-sign.bin
TOS=$IMG_DIR/tos.bin
TOSSIGN=$IMG_DIR/tos-sign.bin
UBOOT=$IMG_DIR/u-boot.bin
UBOOTSIGN=$IMG_DIR/u-boot-sign.bin
FDL1=$IMG_DIR/fdl1.bin
FDL1SIGN=$IMG_DIR/fdl1-sign.bin
FDL2=$IMG_DIR/fdl2.bin
FDL2SIGN=$IMG_DIR/fdl2-sign.bin
VBMETA=$IMG_DIR/vbmeta.img

declare -A ImageArray
declare -A SharkModemImgArr
declare -A PikeModemImgArr
declare -A Sharkl5ModemImgArr
declare -A KeyArray

SharkModemImgArr=( \
             [l_modem]="" \
             [l_ldsp]="" \
             [l_gdsp]="" \
             [pm_sys]="" \
             )
PikeModemImgArr=( \
             [w_modem]="" \
             [w_gdsp]="" \
             [pm_sys]="" \
             )
Sharkl5ModemImgArr=( \
             [l_modem]="" \
             [l_ldsp]="" \
             [l_gdsp]="" \
             [pm_sys]="" \
             [l_agdsp]="" \
             [l_cdsp]="" \
             )
ImageArray=( \
             [boot]=$IMG_DIR/boot.img \
             [recovery]=$IMG_DIR/recovery.img \
             [dtb]=$IMG_DIR/dtb.img \
             [dtbo]=$IMG_DIR/dtbo.img \
             [system]=$IMG_DIR/system.img \
             [vendor]=$IMG_DIR/vendor.img \
             [product]=$IMG_DIR/product.img \
             )
KeyArray=( \
           [boot]=$CFGPATH/rsa4096_boot.pem \
           [recovery]=$CFGPATH/rsa4096_recovery.pem \
           [dtb]=$CFGPATH/rsa4096_boot.pem \
           [dtbo]=$CFGPATH/rsa4096_boot.pem \
           [system]=$CFGPATH/rsa4096_system.pem \
           [vendor]=$CFGPATH/rsa4096_vendor.pem \
           [product]=$CFGPATH/rsa4096_product.pem \
           )

# ********* #
# functions #
# ********* #
getRollbackIndex()
{
    rollback_index=0
    name=avb_version_$1
    rollback_index=`sed -n '/'$name'/p'  $VER_CONFIG | sed -n 's/'$name'=//gp'`
    echo "$1 rollback_index = $rollback_index"
}

getImageName(){
    local imagename=$1
    echo ${imagename##*/}
}

getImageSize()
{
    partion=$1
    size=0

    size=`awk '/Partition id="'$partion'"/{print $3}' $PAC_CONFILE | cut -d\" -f2`
    if [ $size -gt 0 ]; then
        echo "$1 partion size = $size MB"
        sizeInByte=$(expr $size \* $MB)
        echo "sizeInByte = $sizeInByte"
    else
        sizeInByte=0
        echo "get partion $partion size failed, exit!!"
        return
    fi
}

AvbSignDatcp()
{
    image=$1
    partion=$2
    key=$3
    DAT_VBMETA=${IMG_DIR}/dat_vbmeta.img

    echo "Sign $partion ......"
    echo "imgname = $image"
    echo "used key: $key"
    echo "rollback_index = $rollback_index"
    getImageSize $partion
    if [ -f $image ]; then
        $SPLIT_TOOL $image
        divname=$image.div
        $AVB_TOOL add_hash_footer --image $divname \
                                  --partition_size $sizeInByte \
                                  --partition_name $partion \
                                  --algorithm SHA256_RSA4096 \
                                  --key $key \
                                  --rollback_index $rollback_index \
                                  --output_vbmeta_image $DAT_VBMETA \
                                  --do_not_append_vbmeta_image
        if [ $? -ne 0 ]; then
            echo "Sign $image failed!"
            rm $divname
        fi
        echo "found div file, append vbmeta"
        $AVB_TOOL append_vbmeta_image --image $image \
                                      --partition_size $sizeInByte \
                                      --vbmeta_image $DAT_VBMETA
        if [ $? -ne 0 ]; then
            echo "Sign $image failed!"
            rm $divname
        else
            echo "Sign complete."
            echo
        fi
        rm $divname
        rm $DAT_VBMETA
    else
        echo -e "\033[31m file not found: $image, pls check! \033[0m"
    fi
}

AvbSignNormal()
{
    image=$1
    partion=$2
    key=$3

    echo "Sign $partion ......"
    echo "imgname = $image"
    echo "used key: $key"
    echo "rollback_index = $rollback_index"
    getImageSize $partion
    if [ -f $image ]; then
        $AVB_TOOL add_hash_footer --image $image \
                                  --partition_size $sizeInByte \
                                  --partition_name $partion \
                                  --algorithm SHA256_RSA4096 \
                                  --key $key \
                                  --rollback_index $rollback_index
        echo "Sign complete."
        echo
    else
        echo -e "\033[31m file not found: $image, pls check! \033[0m"
    fi
}

RemoveFooter()
{
    $AVB_TOOL erase_footer --image $1
}

ModemSignShark()
{
    getRollbackIndex modem
    for image in $@
    do
        if [ -f ${SharkModemImgArr[$image]} ]; then
            echo "sign $image"
            echo "sign img ${SharkModemImgArr[$image]}"
            RemoveFooter ${SharkModemImgArr[$image]}
            if [ $image == "l_modem" ]; then
                AvbSignDatcp ${SharkModemImgArr[$image]} $image $MODEM_KEY
            else
                AvbSignNormal ${SharkModemImgArr[$image]} $image $MODEM_KEY
            fi
        else
            echo -e "\033[31m file not found: $image, pls check! \033[0m"
        fi
    done
}

echo_exit(){
    echo -e "\033[41;37m$1 \033[0m"
}

echo_eval(){
    local eg=$1
    eval eval_name="\${$eg[@]}"

    if [ -n "$eg" ] && [[ `echo ${eval_name} | wc -L` -ge "1" ]];then
        echo "[$eg: ${eval_name}]"
    else
        echo_exit "[$eg: ${eval_name} error!]"
        exit 1
    fi
}

doReplaceIni()
{
    sed -i "\#$2#s##/$IMG_DIR/cp_sign/$3/$(getImageName $2)#g" $1
}

doModemCopySharkl3()
{
    echo "============================================================"
    echo "enter doModemCopySharkl3"
    echo ini = $1
    echo dst = $2
    echo directory = $3

    modem_lte=`sed -n '/Modem_LTE=1@/p'  $1 | sed -n 's/Modem_LTE=1@.//gp'`
    echo_eval modem_lte
    SharkModemImgArr[l_modem]=$2$(getImageName $modem_lte)
    doReplaceIni $1 $modem_lte $3

    dsp_lte=`sed -n '/DSP_LTE_LTE=1@/p'  $1 | sed -n 's/DSP_LTE_LTE=1@.//gp'`
    echo_eval dsp_lte
    SharkModemImgArr[l_ldsp]=$2$(getImageName $dsp_lte)
    doReplaceIni $1 $dsp_lte $3

    dsp_gge=`sed -n '/DSP_LTE_GGE=1@/p'  $1 | sed -n 's/DSP_LTE_GGE=1@.//gp'`
    echo_eval dsp_gge
    SharkModemImgArr[l_gdsp]=$2$(getImageName $dsp_gge)
    doReplaceIni $1 $dsp_gge $3

    dfs=`sed -n '/DFS=1@/p'  $1 | sed -n 's/DFS=1@.//gp'`
    echo_eval dfs
    SharkModemImgArr[pm_sys]=$2$(getImageName $dfs)
    doReplaceIni $1 $dfs $3

    cp $TOPDIR$modem_lte $2 -rf
    cp $TOPDIR$dsp_lte $2 -rf
    cp $TOPDIR$dsp_gge $2 -rf
    cp $TOPDIR$dfs $2 -rf

    pac_xml=`sed -n '/CONFILE=/p'  $1 | sed -n 's/CONFILE=.//gp'`
    PAC_CONFILE=$TOPDIR/$pac_xml
    echo "pac file: $PAC_CONFILE"

    echo "leave doModemCopySharkl3"
    echo "============================================================"
}

doModemCopySharkle()
{
    echo "============================================================"
    echo "enter doModemCopySharkle"
    echo ini = $1
    echo dst = $2
    echo directory = $3

    modem_lte=`sed -n '/Modem_WLTE=1@/p'  $1 | sed -n 's/Modem_WLTE=1@.//gp'`
    echo_eval modem_lte
    SharkModemImgArr[l_modem]=$2$(getImageName $modem_lte)
    doReplaceIni $1 $modem_lte $3

    dsp_lte=`sed -n '/DSP_WLTE_LTE=1@/p'  $1 | sed -n 's/DSP_WLTE_LTE=1@.//gp'`
    echo_eval dsp_lte
    SharkModemImgArr[l_ldsp]=$2$(getImageName $dsp_lte)
    doReplaceIni $1 $dsp_lte $3

    dsp_gge=`sed -n '/DSP_WLTE_GGE=1@/p'  $1 | sed -n 's/DSP_WLTE_GGE=1@.//gp'`
    echo_eval dsp_gge
    SharkModemImgArr[l_gdsp]=$2$(getImageName $dsp_gge)
    doReplaceIni $1 $dsp_gge $3

    dfs=`sed -n '/DFS=1@/p'  $1 | sed -n 's/DFS=1@.//gp'`
    echo_eval dfs
    SharkModemImgArr[pm_sys]=$2$(getImageName $dfs)
    doReplaceIni $1 $dfs $3

    cp $TOPDIR$modem_lte $2 -rf
    cp $TOPDIR$dsp_lte $2 -rf
    cp $TOPDIR$dsp_gge $2 -rf
    cp $TOPDIR$dfs $2 -rf

    pac_xml=`sed -n '/CONFILE=/p'  $1 | sed -n 's/CONFILE=.//gp'`
    PAC_CONFILE=$TOPDIR/$pac_xml
    echo "pac file: $PAC_CONFILE"

    echo "leave doModemCopySharkle"
    echo "============================================================"
}

ModemSignPike()
{
    getRollbackIndex modem
    for image in $@
    do
        if [ -f ${PikeModemImgArr[$image]} ]; then
            echo "sign $image"
            echo "sign img ${PikeModemImgArr[$image]}"
            RemoveFooter ${PikeModemImgArr[$image]}
            if [ $image == "w_modem" ]; then
                AvbSignDatcp ${PikeModemImgArr[$image]} $image $MODEM_KEY
            else
                AvbSignNormal ${PikeModemImgArr[$image]} $image $MODEM_KEY
            fi
        else
            echo -e "\033[31m file not found: $image, pls check! \033[0m"
        fi
    done
}

doImgCopyShark()
{
    if [ "$secboot" != "SPRD" ]; then
        echo none secure prj,return
        return
    fi

    dir=$(ls -l /$OUTDIR/ |awk '/^d/ {print $NF}')
    for i in $dir
    do
        echo found dir $i
        if [[ $ChipType = "sharkl3" ]];then
            doModemCopySharkl3 $OUTDIR/$i/pac.ini $OUTDIR/$i/ $i
        else
            doModemCopySharkle $OUTDIR/$i/pac.ini $OUTDIR/$i/ $i
        fi
        doAvbSign
    done
}

doModemCopyPike()
{
    echo "============================================================"
    echo "enter doModemCopyPike"
    echo ini = $1
    echo dst = $2
    echo directory = $3

    modem_lte=`sed -n '/Modem_W=1@/p'  $1 | sed -n 's/Modem_W=1@.//gp'`
    echo_eval modem_lte
    PikeModemImgArr[w_modem]=$2$(getImageName $modem_lte)
    doReplaceIni $1 $modem_lte $3

    dsp_gge=`sed -n '/DSP_GSM=1@/p'  $1 | sed -n 's/DSP_GSM=1@.//gp'`
    echo_eval dsp_gge
    PikeModemImgArr[w_gdsp]=$2$(getImageName $dsp_gge)
    doReplaceIni $1 $dsp_gge $3

    dfs=`sed -n '/DFS=1@/p'  $1 | sed -n 's/DFS=1@.//gp'`
    echo_eval dfs
    PikeModemImgArr[pm_sys]=$2$(getImageName $dfs)
    doReplaceIni $1 $dfs $3

    cp $TOPDIR$modem_lte $2 -rf
    cp $TOPDIR$dsp_gge $2 -rf
    cp $TOPDIR$dfs $2 -rf

    echo "leave doModemCopyPike"
    echo "============================================================"
}

doImgCopyPike()
{
    if [ "$secboot" != "SPRD" ]; then
        echo none secure prj,return
        return
    fi

    dir=$(ls -l /$OUTDIR/ |awk '/^d/ {print $NF}')
    for i in $dir
    do
        echo found dir $i
        doModemCopyPike $OUTDIR/$i/pac.ini $OUTDIR/$i/ $i
        doAvbSign
    done
}

ModemSignSharkl5()
{
    getRollbackIndex modem
    for image in $@
    do
        if [ -f ${Sharkl5ModemImgArr[$image]} ]; then
            echo "sign $image"
            echo "sign img ${Sharkl5ModemImgArr[$image]}"
            RemoveFooter ${Sharkl5ModemImgArr[$image]}
            if [ $image == "l_modem" ]; then
                AvbSignDatcp ${Sharkl5ModemImgArr[$image]} $image $MODEM_KEY
            else
                AvbSignNormal ${Sharkl5ModemImgArr[$image]} $image $MODEM_KEY
            fi
        else
            echo -e "\033[31m file not found: $image, pls check! \033[0m"
        fi
    done
}

doModemCopySharkl5()
{
    echo "============================================================"
    echo "enter doModemCopySharkl5"
    echo ini = $1
    echo dst = $2
    echo directory = $3

    modem_lte=`sed -n '/Modem_LTE=1@/p'  $1 | sed -n 's/Modem_LTE=1@.//gp'`
    echo_eval modem_lte
    Sharkl5ModemImgArr[l_modem]=$2$(getImageName $modem_lte)
    doReplaceIni $1 $modem_lte $3

    dsp_lte=`sed -n '/DSP_LTE_LTE=1@/p'  $1 | sed -n 's/DSP_LTE_LTE=1@.//gp'`
    echo_eval dsp_lte
    Sharkl5ModemImgArr[l_ldsp]=$2$(getImageName $dsp_lte)
    doReplaceIni $1 $dsp_lte $3

    dsp_gge=`sed -n '/DSP_LTE_GGE=1@/p'  $1 | sed -n 's/DSP_LTE_GGE=1@.//gp'`
    echo_eval dsp_gge
    Sharkl5ModemImgArr[l_gdsp]=$2$(getImageName $dsp_gge)
    doReplaceIni $1 $dsp_gge $3

    dfs=`sed -n '/DFS=1@/p'  $1 | sed -n 's/DFS=1@.//gp'`
    echo_eval dfs
    Sharkl5ModemImgArr[pm_sys]=$2$(getImageName $dfs)
    doReplaceIni $1 $dfs $3

    agdsp=`sed -n '/DSP_LTE_AG=1@/p'  $1 | sed -n 's/DSP_LTE_AG=1@.//gp'`
    echo_eval agdsp
    Sharkl5ModemImgArr[l_agdsp]=$2$(getImageName $agdsp)
    doReplaceIni $1 $agdsp $3

    cdsp=`sed -n '/DSP_LTE_CDMA=1@/p'  $1 | sed -n 's/DSP_LTE_CDMA=1@.//gp'`
    echo_eval cdsp
    Sharkl5ModemImgArr[l_cdsp]=$2$(getImageName $cdsp)
    doReplaceIni $1 $cdsp $3

    cp $TOPDIR$modem_lte $2 -rf
    cp $TOPDIR$dsp_lte $2 -rf
    cp $TOPDIR$dsp_gge $2 -rf
    cp $TOPDIR$dfs $2 -rf
    cp $TOPDIR$agdsp $2 -rf
    cp $TOPDIR$cdsp $2 -rf

    pac_xml=`sed -n '/CONFILE=/p'  $1 | sed -n 's/CONFILE=.//gp'`
    PAC_CONFILE=$TOPDIR/$pac_xml
    echo "pac file: $PAC_CONFILE"

    echo "leave doModemCopySharkl5"
    echo "============================================================"
}

doImgCopySharkl5()
{
    if [ "$secboot" != "SPRD" ]; then
        echo none secure prj,return
        return
    fi

    dir=$(ls -l /$OUTDIR/ |awk '/^d/ {print $NF}')
    for i in $dir
    do
        echo found dir $i
        doModemCopySharkl5 $OUTDIR/$i/pac.ini $OUTDIR/$i/ $i
        doAvbSign
    done
}

doAvbSign()
{
	case $ChipType in
	sharkl3|sharkle)
	    echo "************************************************************"
	    ModemSignShark l_modem l_gdsp l_ldsp pm_sys
	    echo "************************************************************"
	;;
	pike2)
	    echo "************************************************************"
	    ModemSignPike w_modem w_gdsp pm_sys
	    echo "************************************************************"
	;;
	sharkl5)
	    echo "************************************************************"
	    ModemSignSharkl5 l_modem l_gdsp l_ldsp pm_sys l_agdsp l_cdsp
	    echo "************************************************************"
	;;
	*)
	    echo "[== not support product ==]"
	    return;;
	esac

}

doPacpy()
{
    echo project= $PROJECT
    echo board = $BOARD
    echo out = $OUTDIR
    carrier=$PRODUCT_SET_CARRIERS
    if [ -z "$carrier" ]; then
        echo run no carrier
        python $PAC_PY --project "$PROJECT" --board "$BOARD" --out "$OUTDIR"
    else
        echo $carrier
        python $PAC_PY --project "$PROJECT" --board "$BOARD" --out "$OUTDIR" --carrier "$carrier"
    fi
}

doInit()
{
    echo secboot is $SECBOOT
    if [[ $PRODUCT =~ "9863" ]];then
        ChipType=sharkl3
    elif [[ $PRODUCT =~ "9832" ]];then
        ChipType=sharkle
    elif [[ $PRODUCT =~ "7731" ]];then
        ChipType=pike2
    elif [[ $PRODUCT =~ "ums512" ]];then
        ChipType=sharkl5
    else
        ChipType=""
    fi
}

# ************* #
# main function #
# ************* #
echo "secureboot sign AOSP modem script, ver 0.30"
doInit
echo chiptype $ChipType
case $ChipType in
sharkl3|sharkle)
    echo "shark series"
    doPacpy
    doImgCopyShark
;;
pike2)
    echo "pike2 series"
    doPacpy
    doImgCopyPike
;;
sharkl5)
    echo "sharkl5 series"
    doPacpy
    doImgCopySharkl5
;;
*)
    echo "[== not support product ==]"
    return;;
esac
