#!/bin/bash

ROOTDIR=$(pwd)
KEY_PATH=$ROOTDIR/../../config
CERTPATH=$ROOTDIR/../bin
PRIMARYCERT_MASK=$1

if [ "$1" = "" ]
	then echo -e "\033[31m please input debug mask val such as 0xffffffff  eg.\033[0m"
	    exit
fi

echo -e "\033[36m Note:Only 9863a/7731e/9832e device series padding is pkcs15, The other is pss .\033[0m"

read -p "enter your device padding type [ 1:pss 2:pkcs15 ]    " type
if  [[ $type -eq 1 ]];then
    echo "your device padding is pss"
    PSS_FLAG=pss
elif [[ $type -eq 2 ]]; then
    echo "your device padding is pkcs15"
    PSS_FLAG=pkcs15
else
    echo -e "\033[31m pls re-run this script and make a choose: pss or pkcs15 \033[0m"
    exit
fi

doSprdmkprimarycert()
{
  $ROOTDIR/../bin/sprd_mkprimarycert $PRIMARYCERT_MASK $KEY_PATH $PSS_FLAG
}

doSprdmkprimarycert

if [ -f primary_debug.cert ] ;
	then mv primary_debug.cert $ROOTDIR/../bin
		echo -e "\033[32m create primary_debug.cert sucessfull! \033[0m"
fi

if [ ! -f $CERTPATH/primary_debug.cert ] ;
	then echo -e "\033[31m primary_debug.cert is not exist,pls execute the script in mkprimarycert document  first! \033[0m "
fi

if [ ! -f $CERTPATH/u-boot-spl-16k-sign.bin -a ! -f $CERTPATH/u-boot-spl-16k-emmc-sign.bin -a ! -f $CERTPATH/u-boot-spl-16k-ufs-sign.bin ] ;
	then echo -e "\033[31m u-boot-spl-16k-sign.bin/u-boot-spl-16k-ufs-sign.bin/u-boot-spl-16k-emmc-sign.bin is not exist,pls execute make chipram  first! \033[0m "
fi

if [ ! -f $CERTPATH/fdl1-sign.bin ] ;
	then echo -e "\033[31m fdl1-sign.bin is not exist, pls execute make chipram  first! \033[0m "
fi

echo -e "next enter your device socid and debug mask :   "
echo -n " pls input parameter like:  0xfacd...de  0xffff eg. "
    read socid mask
if [ "$socid" = "" -o "$mask" = "" ];then
	 echo -e "\033[31m pls input command: mkdbimg 0xface...de 0xffff eg.\033[0m "
     exit
 fi


IMAGE_FDL1=$CERTPATH/fdl1-sign.bin
IMAGE_SPL=$CERTPATH/u-boot-spl-16k-sign.bin
IMAGE_EMMC_SPL=$CERTPATH/u-boot-spl-16k-emmc-sign.bin
IMAGE_UFS_SPL=$CERTPATH/u-boot-spl-16k-ufs-sign.bin
KEY_PATH=$ROOTDIR/../config
CERT=$CERTPATH/primary_debug.cert
SOCID=$socid
MASK=$mask

dosprdmkdbimg()
{
if [ -f $IMAGE_FDL1 ] ; then
	$ROOTDIR/../bin/sprd_mkdbimg $IMAGE_FDL1 $CERT $KEY_PATH $SOCID $MASK $MASK $PSS_FLAG
	echo -e "\033[33m mkdbimg fdl1-sign.bin ok!\033[0m "
fi

if [ -f $IMAGE_SPL ] ;then
	$ROOTDIR/../bin/sprd_mkdbimg $IMAGE_SPL $CERT $KEY_PATH $SOCID $MASK $MASK $PSS_FLAG
	echo -e "\033[33m mkdbimg spl-sign.bin ok! \033[0m "
fi

if [ -f $IMAGE_EMMC_SPL ] ;then
	$ROOTDIR/../bin/sprd_mkdbimg $IMAGE_EMMC_SPL $CERT $KEY_PATH $SOCID $MASK $MASK $PSS_FLAG
	echo -e "\033[33m mkdbimg spl-emmc-sign.bin ok! \033[0m "
fi

if [ -f $IMAGE_UFS_SPL ] ;then
	$ROOTDIR/../bin/sprd_mkdbimg $IMAGE_UFS_SPL $CERT $KEY_PATH $SOCID $MASK $MASK $PSS_FLAG
	echo -e "\033[33m mkdbimg spl-ufs-sign.bin ok! \033[0m "
fi
}

dosprdmkdbimg
