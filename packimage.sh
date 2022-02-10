#!/bin/sh

SECURE_BOOT=$(get_build_var PRODUCT_SECURE_BOOT)
SECURE_BOOT_KCE=$(get_build_var PRODUCT_SECURE_BOOT_KCE)
PSS_FLAG=$(get_build_var PKCS1_PSS_FLAG)
HOST_OUT=$(get_build_var HOST_OUT_EXECUTABLES)
PRODUCT_OUT=$(get_build_var PRODUCT_OUT)
TARGET_ARCH=$(get_build_var TARGET_ARCH)
CURPATH=$(pwd)
TA_DESTDIR=$CURPATH/vendor/sprd/proprietories-source/packimage_scripts/signimage
CERTPATH=$CURPATH/vendor/sprd/proprietories-source/packimage_scripts/signimage/sansa/output
CFGPATH=$CURPATH/vendor/sprd/proprietories-source/packimage_scripts/signimage/sprd/config
KCE_TYPE=$(get_build_var SECURE_BOOT_KCE)
if [[ "128" = $KCE_TYPE ]]; then
        AESKEY=$CFGPATH/aeskey_128
    else
        AESKEY=$CFGPATH/aeskey
fi
DESTDIR=$CURPATH/vendor/sprd/proprietories-source/packimage_scripts/signimage/sprd/mkdbimg/bin
SPL=$PRODUCT_OUT/u-boot-spl-16k.bin
SPLSIGN=$PRODUCT_OUT/u-boot-spl-16k-sign.bin
SPL_EMMC=$PRODUCT_OUT/u-boot-spl-16k-emmc.bin
SPL_EMMCSIGN=$PRODUCT_OUT/u-boot-spl-16k-emmc-sign.bin
SPL_UFS=$PRODUCT_OUT/u-boot-spl-16k-ufs.bin
SPL_UFSSIGN=$PRODUCT_OUT/u-boot-spl-16k-ufs-sign.bin
SML=$PRODUCT_OUT/sml.bin
SMLSIGN=$PRODUCT_OUT/sml-sign.bin
TOS=$PRODUCT_OUT/tos.bin
TOSSIGN=$PRODUCT_OUT/tos-sign.bin
TEECFG=$PRODUCT_OUT/teecfg.bin
TEECFGSIGN=$PRODUCT_OUT/teecfg-sign.bin
SECVM=$PRODUCT_OUT/secvm.bin
SECVMSIGN=$PRODUCT_OUT/secvm-sign.bin
MVCFG=$PRODUCT_OUT/mvconfig.bin
MVCFGSIGN=$PRODUCT_OUT/mvconfig-sign.bin
MOB=$PRODUCT_OUT/mobilevisor.bin
MOBSIGN=$PRODUCT_OUT/mobilevisor-sign.bin
UBOOTDT=$PRODUCT_OUT/u-boot-dtb.bin
UBOOTDTSIGN=$PRODUCT_OUT/u-boot-dtb-sign.bin
UBOOT=$PRODUCT_OUT/u-boot.bin
UBOOTSIGN=$PRODUCT_OUT/u-boot-sign.bin
FDL1=$PRODUCT_OUT/fdl1.bin
FDL1SIGN=$PRODUCT_OUT/fdl1-sign.bin
FDL2=$PRODUCT_OUT/fdl2.bin
FDL2SIGN=$PRODUCT_OUT/fdl2-sign.bin
UBOOTAUTO=$PRODUCT_OUT/u-boot_autopoweron.bin
UBOOTAUTOSIGN=$PRODUCT_OUT/u-boot_autopoweron-sign.bin
VBMETA=$PRODUCT_OUT/vbmeta.img
DDR_SCAN=$PRODUCT_OUT/ddr_scan.bin
DDR_SCANSIGN=$PRODUCT_OUT/ddr_scan-sign.bin

#This switch controls whether the sansa debug certificate is added to the tail of spl
#0: disable
#1: enable
debug_cert=0

checkEnv()
{
    PYTHON_VERSION=$(python3 -V 2>&1|grep '^Python 3\.[0-9]\.[0-9]')
    if [[ -z $PYTHON_VERSION ]]
    then
        echo "No python3 found! Install by execute \"sudo apt-get install python3\"[ERROR]"
        return
    fi
    #echo check python3 version $PYTHON_VERSION [OK]
}

getModuleName()
{
    local name="allmodules"
    if [ $# -gt 0 ]; then
        for loop in $@
        do
            case $loop in
            "chipram")
            name="chipram"
            break
            ;;
            "bootloader")
            name="bootloader"
            break
            ;;
            "bootimage")
            name="bootimage"
            break
            ;;
            "recoveryimage")
            name="recoveryimage"
            break
            ;;
            "prodnvimage")
            name="prodnvimage"
            break
            ;;
            "systemimage")
            name="systemimage"
            break
            ;;
            "vendorimage")
            name="vendorimage"
            break
            ;;
            "userdataimage")
            name="userdataimage"
            break
            ;;
            "cacheimage")
            name="cacheimage"
            break
            ;;
            "trusty")
            name="trusty"
            break
            ;;
            "teecfg")
            name="teecfg"
            break
            ;;
            "sml")
            name="sml"
            break
            ;;
            "vbmetaimage")
            name="vbmetaimage"
            break
            ;;
            "vbmetaimage-nodeps")
            name="vbmetaimage"
            break
            ;;
            "clean")
            name="clean"
            break
            ;;
            *)
            ;;
            esac
        done
    fi
    echo $name
}

getCertLevel()
{
    local level
    case $1 in
        $SPLSIGN)
            level=3
            ;;
        $SPL_EMMCSIGN)
            level=3
            ;;
        $SPL_UFSSIGN)
            level=3
            ;;
        $FDL1SIGN)
            level=3
            ;;
        $UBOOTSIGN)
            level=2
            ;;
        $FDL2SIGN)
            level=2
            ;;
        *)
            level=1
            ;;
    esac
    echo $level
}

doImgHeaderInsert()
{
    local NO_SECURE_BOOT
    local remove_orig_file_if_succeed=1
    local ret

    if [ "NONE" = $SECURE_BOOT ]; then
        NO_SECURE_BOOT=1
    else
        NO_SECURE_BOOT=0
    fi

    for loop in $@
    do
        if [ -f $loop ] ; then
            $HOST_OUT/imgheaderinsert $loop $NO_SECURE_BOOT $remove_orig_file_if_succeed
            ret=$?
            if [ "$ret" = "1" ]; then
                 echo "####imgheaderinsert $loop NO_SECURE_BOOT=$NO_SECURE_BOOT remove_orig_file_if_succeed=$remove_orig_file_if_succeed failed!####"
                 return 1
            fi
        else
            echo "#### no $loop,please check ####"
        fi
    done
    return 0
}
dorename()
{
    for filename in $PRODUCT_OUT/*-cipher*
    do
        mv $filename ${filename/-cipher/}
    done
}
doAESencrypt()
{
    if [ "NONE" = $SECURE_BOOT ]; then
        return
    fi
    if [ "DISABLE" = $SECURE_BOOT_KCE ]; then
        return
    fi
	for image in $@
	do
		if [ -f $image ]; then
			$HOST_OUT/sprd_encrypt $AESKEY   $image
		else
			echo -e "\033[31m ####  no $image or aeskey file, pls check #### \033[0m"
		fi
	done
    dorename
}
dosprdcopy()
{
    if [ -f $SPLSIGN ];then
        cp $SPLSIGN $DESTDIR
        #echo -e "\033[33m copy spl-sign.bin finish!\033[0m"
    fi

    if [ -f $SPL_EMMCSIGN ];then
        cp $SPL_EMMCSIGN $DESTDIR
        #echo -e "\033[33m copy spl-emmc-sign.bin finish!\033[0m"
    fi

    if [ -f $SPL_UFSSIGN ];then
        cp $SPL_UFSSIGN $DESTDIR
        #echo -e "\033[33m copy spl-ufs-sign.bin finish!\033[0m"
    fi

    if [ -f $FDL1SIGN ]; then
        cp $FDL1SIGN $DESTDIR
        #echo -e "\033[33m copy fdl1-sign.bin finish!\033[0m"
    fi
}

doSignImage()
{
    if [ "NONE" = $SECURE_BOOT ]; then
        return
    fi
    #/*add sprd sign*/
    if [ "SPRD" = $SECURE_BOOT ]; then
        for image in $@
        do
            if [ -f $image ]; then
                if [ "true" = $PSS_FLAG ]; then
                    $HOST_OUT/sprd_sign  $image  $CFGPATH  pss
                else
                    $HOST_OUT/sprd_sign  $image  $CFGPATH  pkcs15
                fi
            else
                echo -e "\033[31m ####  no $image, pls check #### \033[0m"
            fi
        done
        #call this function do copy fdl1&spl to mkdbimg/bin document
        dosprdcopy
    fi

    if [ "SANSA" = $SECURE_BOOT ]; then
        for image in $@
        do
            if [ -f $image ] ; then
                $HOST_OUT/sansa_sign.sh $image $SECURE_BOOT_KCE
                if [ $? -eq 0 ]; then
                    $HOST_OUT/signimage $CERTPATH $image $(getCertLevel $image) $debug_cert
                else
                    echo "sansa_sign result failed"
                fi
            else
                echo "#### no $image,please check ####"
            fi
        done
    fi
}

doPackImage()
{
    if [ "SANSA" = $SECURE_BOOT ]; then
        checkEnv
    fi
    case $(getModuleName "$@") in
        "chipram")
            if (echo $TARGET_ARCH | grep -E 'x86_64') 1>/dev/null 2>&1; then
                doImgHeaderInsert $SPL $SPL_EMMC $SPL_UFS $FDL1 $SECVM $MVCFG $MOB $DDR_SCAN

                if [ "$?" = "1" ]; then
                   return 1
                fi
                doAESencrypt $SECVMSIGN $MVCFGSIGN $MOBSIGN $SPLSIGN $SPL_EMMCSIGN $SPL_UFSSIGN
                doSignImage $SPLSIGN $SPL_EMMCSIGN $SPL_UFSSIGN $FDL1SIGN $SECVMSIGN $MVCFGSIGN $MOBSIGN $DDR_SCANSIGN
            else
                doImgHeaderInsert $SPL $SPL_EMMC $SPL_UFS $FDL1 $DDR_SCAN
                if [ "$?" = "1" ]; then
                   return 1
                fi
                doSignImage $SPLSIGN $SPL_EMMCSIGN $SPL_UFSSIGN $FDL1SIGN $DDR_SCANSIGN
            fi
            ;;
        "bootloader")
            if (echo $TARGET_ARCH | grep -E 'x86_64') 1>/dev/null 2>&1; then
                doImgHeaderInsert  $FDL2 $UBOOT $UBOOTAUTO
                if [ "$?" = "1" ]; then
                   return 1
                fi

                doAESencrypt $UBOOTSIGN
                doSignImage  $FDL2SIGN $UBOOTSIGN $UBOOTAUTOSIGN
            else
                doImgHeaderInsert $UBOOT $FDL2 $UBOOTAUTO
                if [ "$?" = "1" ]; then
                   return 1
                fi

                doSignImage $UBOOTSIGN $FDL2SIGN $UBOOTAUTOSIGN
            fi
            ;;
        "bootimage")
		return 1
	    ;;
        "recoveryimage")
		return 1
	    ;;
        "prodnvimage")
		return 1
	    ;;
        "systemimage")
		return 1
	    ;;
        "vendorimage")
		return 1
	    ;;
        "userdataimage")
		return 1
	    ;;
        "cacheimage")
		return 1
	    ;;
        "trusty")
                #the next line is for dynamic TA
                python $TA_DESTDIR/dynamicTA/genkey/main_process.py $PRODUCT_OUT $TA_DESTDIR
                doImgHeaderInsert $TOS
                if [ "$?" = "1" ]; then
                   return 1
                fi
                doSignImage $TOSSIGN
            ;;
        "teecfg")
                doImgHeaderInsert $TEECFG
                if [ "$?" = "1" ]; then
                   return 1
                fi
                doSignImage $TEECFGSIGN
	    ;;
        "sml")
                doImgHeaderInsert $SML
                if [ "$?" = "1" ]; then
                   return 1
                fi
                doSignImage $SMLSIGN
            ;;

        "allmodules")
            if [ "NONE" = $SECURE_BOOT ]; then
                if (echo $TARGET_ARCH | grep -E 'x86_64') 1>/dev/null 2>&1 ; then
                    doImgHeaderInsert $SPL $SPL_EMMC $SPL_UFS $FDL1 $SECVM $MVCFG $MOB  $FDL2  $UBOOT $UBOOTAUTO $DDR_SCAN
                else
                    #the next line is for dynamic TA
                    python $TA_DESTDIR/dynamicTA/genkey/main_process.py $PRODUCT_OUT $TA_DESTDIR
                    doImgHeaderInsert $SPL $SPL_EMMC $SPL_UFS $UBOOT $FDL1 $FDL2 $UBOOTAUTO $SML $TOS $TEECFG $DDR_SCANSIGN
                fi
            else
                if (echo $TARGET_ARCH | grep -E 'x86_64') 1>/dev/null 2>&1 ; then
                    doImgHeaderInsert $SPL $SPL_EMMC $SPL_UFS $FDL1 $SECVM $MVCFG $MOB $FDL2 $UBOOT $DDR_SCAN
                    if [ "$?" = "1" ]; then
                       return 1
                    fi
                    doAESencrypt  $SPLSIGN $SPL_EMMCSIGN $SPL_UFSSIGN $SECVMSIGN $MVCFGSIGN $MOBSIGN $UBOOTSIGN
                    doSignImage $SPLSIGN $SPL_EMMCSIGN $SPL_UFSSIGN $FDL1SIGN $SECVMSIGN $MVCFGSIGN $MOBSIGN $FDL2SIGN $UBOOTSIGN $DDR_SCANSIGN
                else
                    #the next line is for dynamic TA
                    python $TA_DESTDIR/dynamicTA/genkey/main_process.py $PRODUCT_OUT $TA_DESTDIR
                    doImgHeaderInsert $SPL $SPL_EMMC $SPL_UFS $UBOOT $FDL1 $FDL2 $UBOOTAUTO $SML $TOS $TEECFG $DDR_SCAN
                    if [ "$?" = "1" ]; then
                       return 1
                    fi
                    doSignImage $SPLSIGN $SPL_EMMCSIGN $SPL_UFSSIGN $UBOOTSIGN $FDL1SIGN $FDL2SIGN $SMLSIGN $TOSSIGN $TEECFGSIGN $UBOOTAUTOSIGN $DDR_SCANSIGN
                fi
#insert image header always with hash for backup partition  of android O vbmeta.img
                $HOST_OUT/imgheaderinsert $VBMETA 1 1
            fi
            ;;
        "vbmetaimage")
            $HOST_OUT/imgheaderinsert $VBMETA 1 1
            ;;
        "clean")
            #do nothing
            ;;
        *)
            ;;
    esac
}


doPackImage "$@"
