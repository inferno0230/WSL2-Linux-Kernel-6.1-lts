#! /bin/bash
#
# Kernel compile script for WSL2 kernel
# Copyright (C) 2023-2024 InFeRnO.

# Setup environment
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
clear='\033[0m'
KERNEL_PATH=$PWD
ARCH=x86
DEFCONFIG=custom_defconfig
LLVM_DIR=.clang
LLVM_VER="llvm-20.1.3-x86_64"
LLVM_URL="https://cdn.kernel.org/pub/tools/llvm/files/$LLVM_VER.tar.gz"
export PATH=$PWD/.clang/$LLVM_VER/bin:$PATH
BUILD_CC="LLVM=1"

clone_clang() {
    mkdir $LLVM_DIR
    wget -O llvm.tar.gz $LLVM_URL
    tar -xzf llvm.tar.gz -C $LLVM_DIR
}

ArchLinux() {
    # Check if yay is installed
    if ! command -v yay &> /dev/null
    then
        echo -e "${red}yay is not installed, please install it first!${clear}"
        exit
    else
        yay -S lineageos-devel aosp-devel zstd tar wget curl base-devel lib32-ncurses lib32-zlib lib32-readline cpio flex bison pahole-git dwarves wget --noconfirm
    fi
}

Ubuntu() {
    sudo apt install build-essential bc flex bison dwarves libssl-dev libelf-dev cpio wget -y
}

regenerate_defconfig() {
    cd $KERNEL_PATH
    make $BUILD_CC O=out ARCH=$ARCH $DEFCONFIG savedefconfig
    cp out/.config arch/$ARCH/configs/$DEFCONFIG
}

build_kernel() {
    cd $KERNEL_PATH
    make CC='ccache clang' CXX='ccache clang++' $BUILD_CC O=out ARCH=$ARCH $DEFCONFIG savedefconfig
    # Begin compilation
    start=$(date +%s)
    make $BUILD_CC O=out ARCH=$ARCH -j`nproc` ${BUILD_CC} 2>&1 | tee error.log
    if [ -f $KERNEL_PATH/out/arch/$ARCH/boot/bzImage ]; then
        make_zip
        echo -e "${green}Kernel Compilation successful.${clear}"
    else
        echo -e "${red}Compilation failed!${clear}"
        echo -e "${red}Check error.log for more info!${clear}"
        exit
    fi
}

distro_check(){ 
    if [ -f /etc/arch-release ]; then
    echo -e "${green}Arch Linux detected!${clear}"
    ArchLinux
elif [ -f /etc/lsb-release ]; then
    echo -e "${green}Debian based distro detected!${clear}"
    Ubuntu
else
    echo -e "${red}Unsupported OS or ARCH!${clear}"
    exit
fi
}

make_zip(){
    zip_name="WSL2-Linux-v6.1.$(grep "^SUBLEVEL =" Makefile | awk '{print $3}')-$(date +"%Y%m%d").zip"
    cd $KERNEL_PATH
    zip out/$zip_name out/arch/$ARCH/boot/bzImage
    echo -e "${green}out: ${KERNEL_PATH}/out/${zip_name}${clear}"
    echo -e "${clear}"
    echo -e "${green}Completed in $(($(date +%s) - start)) seconds.${clear}"
}

start=$(date +%s)

# Parse Args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --regenerate) # To regenerate defconfig
            REGENERATE_DEFCONFIG=true
            shift
            ;;
        --clean) # To clean build kernel
            CLEAN_BUILD=true
            shift
            ;;
        --setup) # install nessesary packages for kbuild
            SETUP=true
            shift
            ;;
        *) # ¯_(ツ)_/¯
            echo "$1: ¯_(ツ)_/¯"
            exit 1
            ;;
    esac
done

if [ "$REGENERATE_DEFCONFIG" = true ]; then
    regenerate_defconfig
    echo -e "${green}Defconfig regenerated successfully!${clear}"
    exit
fi

if [ "$CLEAN_BUILD" = true ]; then
    rm -rf out/
    echo -e "${green}Entire out folder removed.${clear}"
fi

if [ "$SETUP" = true ]; then
    distro_check
fi

if [ -d "$LLVM_DIR" ]; then
    echo -e "${green}LLVM CLANG already exists. Skipping download.${clear}"
else
    clone_clang
fi

build_kernel
