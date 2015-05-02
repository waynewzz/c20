#!/bin/sh
#
# Description	: Android Build Script.
# Authors		: jianjun jiang - jerryjianjun@gmail.com
# Version		: 1.00
# Notes			: None
#
#

export ANDROID_JAVA_HOME=/usr/lib/jvm/java-6-sun/
BUILD_SCRIPT_TOP_DIR=$(cd `dirname $0` ; pwd)

PRODUCT=mbox203 #$2

PROJECT=wing

CONFIG_KERNEL=sun7ismp_android_defconfig
CONFIG_FILESYSTEM_ANDROID=${PROJECT}_${PRODUCT}-eng

ANDROID_SOURCE_TOPDIR=${BUILD_SCRIPT_TOP_DIR}/android4.2/
LICHEE_SOURCE_TOPDIR=${BUILD_SCRIPT_TOP_DIR}/lichee/

setup_environment()
{
	cd ${BUILD_SCRIPT_TOP_DIR} || return 1
}

merge_files()
{
	echo "***  start merge file   ***"

	if [ -f ${BUILD_SCRIPT_TOP_DIR}/lichee/buildroot/dl/gcc-linaro.tar ];then
		echo " ${BUILD_SCRIPT_TOP_DIR}/lichee/buildroot/dl/gcc-linaro.tar exist!!!"
	else
	    cat ${BUILD_SCRIPT_TOP_DIR}/lichee/buildroot/dl/gcc-linaro.tar_* > ${BUILD_SCRIPT_TOP_DIR}/lichee/buildroot/dl/gcc-linaro.tar
	fi

	if [ -f ${BUILD_SCRIPT_TOP_DIR}/android4.2/prebuilts/eclipse/platform/org.eclipse.platform-3.7.2.zip ];then
		echo " ${BUILD_SCRIPT_TOP_DIR}/android4.2/prebuilts/eclipse/platform/org.eclipse.platform-3.7.2.zip exist!!!"
	else
	    cat ${BUILD_SCRIPT_TOP_DIR}/android4.2/prebuilts/eclipse/platform/org.eclipse.platform-3.7.2.zip_* > ${BUILD_SCRIPT_TOP_DIR}/android4.2/prebuilts/eclipse/platform/org.eclipse.platform-3.7.2.zip
	fi

	echo "***  end merge file   ***"

}

switch_branch()
{
	cd ${BUILD_SCRIPT_TOP_DIR}/android4.2/ || return 1
	echo "***  $PWD  ***"
	git checkout ${branch}
	git pull origin ${branch}
	git branch
	cd ${BUILD_SCRIPT_TOP_DIR}/android4.2/external/ || return 1
	echo "***  $PWD  ***"
	git checkout ${branch}
	git pull origin ${branch}
	git branch
	cd ${BUILD_SCRIPT_TOP_DIR}/android4.2/prebuilts/ || return 1
	echo "***  $PWD  ***"
	git checkout ${branch}
	git pull origin ${branch}
	git branch
	cd ${BUILD_SCRIPT_TOP_DIR}/android4.2/prebuilts/gcc/ || return 1
	echo "***  $PWD  ***"
	git checkout ${branch}
	git pull origin ${branch}
	git branch
	cd ${BUILD_SCRIPT_TOP_DIR}/android4.2/frameworks/ || return 1
	echo "***  $PWD  ***"
	git checkout ${branch}
	git pull origin ${branch}
	git branch
	cd ${BUILD_SCRIPT_TOP_DIR}/lichee/ || return 1
	echo "***  $PWD  ***"
	git checkout ${branch}
	git pull origin ${branch}
	git branch
	cd ${BUILD_SCRIPT_TOP_DIR}/lichee/linux-3.3/ || return 1
	echo "***  $PWD  ***"
	git checkout ${branch}	
	git pull origin ${branch}
	git branch
	return 0
}

build_kernel()
{
	
	cd ${LICHEE_SOURCE_TOPDIR} || return 1
	rm lichee/linux-3.3/.config
	./build.sh -p sun7i_android
	return 0
}

build_system()
{
	cd ${ANDROID_SOURCE_TOPDIR} || return 1
	if [ -f ${ANDROID_SOURCE_TOPDIR}out/target/product/${PROJECT}-${PRODUCT}/system/build.prop ];then
		rm ${ANDROID_SOURCE_TOPDIR}out/target/product/${PROJECT}-${PRODUCT}/system/build.prop
		echo "rm ${ANDROID_SOURCE_TOPDIR}out/target/product/${PROJECT}-${PRODUCT}/system/build.prop success!!!"
	else
		echo "file ${ANDROID_SOURCE_TOPDIR}out/target/product/${PROJECT}-${PRODUCT}/system/build.prop not exist!!!"
	fi
	source build/envsetup.sh
	lunch ${CONFIG_FILESYSTEM_ANDROID}
	extract_bsp
	make -j${threads} || return 1
	pack || return 1
}

pack_bootimg()
{
        cd ${ANDROID_SOURCE_TOPDIR} || return 1
	./build.sh -p sun7i_android
        source build/envsetup.sh
        lunch ${CONFIG_FILESYSTEM_ANDROID}
        extract_bsp
        make bootimage || return 1
	echo "pack boot.img OK!" >&2
}

build_ota_package()
{
        cd ${ANDROID_SOURCE_TOPDIR} || return 1
        rm ${ANDROID_SOURCE_TOPDIR}/out/target/product/${PROJECT}-${PRODUCT}/*-ota-*.zip
        source build/envsetup.sh
        lunch ${CONFIG_FILESYSTEM_ANDROID}
	get_uboot
        make otapackage -j${threads} || return 1

        cp -av ${ANDROID_SOURCE_TOPDIR}/out/target/product/${PROJECT}-${PRODUCT}/*-ota-*.zip ${ANDROID_SOURCE_TOPDIR}/out/target/product/${PROJECT}-${PRODUCT}/update.zip || exit 1;

        echo "" >&2
        echo "^_^ ota package have been build. The path is ${RELEASE_DIR}/update.zip" >&2
        return 0
}

threads=8;
kernel=no;
system=no;
branch=no;

if [ -z $1 ]; then
	kernel=yes
	system=yes
fi

while [ "$1" ]; do
    case "$1" in
	-j=*)
	    x=$1
	    threads=${x#-j=}
	    ;;
        -p=*)
            x=$1
		echo ${PROJECT}_prj=${PROJECT}_${x#-p=}-eng > ./prj.sh
            ;;
        -g=*)
            x=$1
	    branch=${x#-g=}
	    echo git branch name:${branch}
            ;;
	-k|--kernel)
	    kernel=yes
	    ;;
	-s|--system)
	    system=yes
	    ;;
        -o|--ota)
                ota=yes
            ;;
        -b|--boot-image)
            bootimage=yes
	    ;;
	-a|--all)
		kernel=yes
		system=yes
	    ;;
	-h|--help)
	    cat >&2 <<EOF
Usage: build.sh [OPTION]
Build script for compile the source of telechips project.

  -j=n                 using n threads when building source project (example: -j=16)
  -k, --kernel         build kernel from source file and using default config file
  -s, --system         build file system from source file
  -b, --bootimg        pack bootimg
  -o, --ota	       build OTA Packet
  -p=n                 which project/platfrom you build  (example: -p=C20_CJ)
  -a, --all            build all, include anything
  -h, --help           display this help and exit
  -g=xx                switch and update git branch (eg: ./build.sh -g=armpc_c30 or ./build.sh -g=ArmCoreEVB_C20)
 
EOF
	    exit 0
	    ;;
	*)
	    echo "build.sh: Unrecognised option $1" >&2
	    exit 1
	    ;;
    esac
    shift
done

if [ -f ./prj.sh ];then
        if [ -x ./prj.sh ];then
               echo ""
        else
               chmod 777 ./prj.sh
        fi	
	source ./prj.sh
	CONFIG_FILESYSTEM_ANDROID=$wing_prj
else
	if [ -z $2 ];then
		echo "e.g : ./build.sh -a -p=mbox203"
		exit 1;
	fi
fi

if [ "$CONFIG_FILESYSTEM_ANDROID" == "wing_mbox203-eng" ];then
	echo $CONFIG_FILESYSTEM_ANDROID
elif [ "$CONFIG_FILESYSTEM_ANDROID" == "wing_k70-eng" ];then
	echo $CONFIG_FILESYSTEM_ANDROID
else
	echo "prouduct name err"
	echo "e.g : ./build.sh -a -p=mbox203"
	exit 1;
fi

setup_environment || exit 1
merge_files || exit 1

if [ "${branch}" != no ]; then
	switch_branch || exit 1
fi

if [ "${kernel}" = yes ]; then
	build_kernel || exit 1
fi

if [ "${system}" = yes ]; then
	build_system || exit 1
fi

if [ "${bootimage}" = yes ]; then
        pack_bootimg || exit 1
fi

if [ "${ota}" = yes ]; then
        build_ota_package || exit 1
fi
exit 0

