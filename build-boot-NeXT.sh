#!/bin/bash
set -e
set -x

DISK=~/next/2gb.diskempty
BOOT_FORMAT=aout

if [ $# -le 1 ]; then
	echo "Usage: $0 [ install [aout|macho [DISK] ] ]"
	echo "Build bootloader: $0"
	echo "Build and install bootsectors: $0 install $BOOT_FORMAT $DISK"
fi

SRC_REPO=https://github.com/freebsd/freebsd-src.git
SRCDIR=~/next/netbsd-src
OBJDIR=~/next/netbsd-obj
NEXT_AOUT=~/next/linux/arch/m68k/tools/next/aout
NEXT_MACHO=~/next/linux/arch/m68k/tools/next/macho
NEXT_DISKLABEL=~/next/linux/arch/m68k/tools/next/next-disklabel
#LOAD_ADDR=4000000

NPROCS=$[$(nproc)*2]

BASEDIR=$(dirname $(readlink -f $0))
cd $BASEDIR

if [ ! -d $SRCDIR ]; then
	git clone $SRC_REPO $SRCDIR
fi

cd $SRCDIR
git checkout netbsd-10
git reset --hard
cat $BASEDIR/netbsd-src-10-NeXT.diff | patch -p1

# Cleanup
#$SRCDIR/build.sh -U -u -j${NPROCS} -O $OBJDIR -m next68k cleandir

set +e
TOOLDIR=$(basename $(dirname $(dirname $(find ~/next/netbsd-obj/ -iname m68k--netbsdelf-gcc))))
set -e

if [ -z "$TOOLDIR" ]; then
	$SRCDIR/build.sh -U -u -j${NPROCS} -O $OBJDIR -m next68k tools
	TOOLDIR=$(basename $(dirname $(dirname $(find $OBJDIR -iname m68k--netbsdelf-gcc))))
fi

BOOTDIR=$SRCDIR/sys/arch/next68k/stand/boot
$OBJDIR/$TOOLDIR/bin/nbmake-next68k -C $BOOTDIR -j${NPROCS}

if [ -z $LOAD_ADDR ]; then
	LOAD_ADDR=$($OBJDIR/$TOOLDIR/bin/m68k--netbsdelf-objdump -D $BOOTDIR/boot.elf|grep '<start>:'|cut -f1 -d' ')
fi

if [ ! -d $(dirname $NEXT_AOUT) ]; then
	mkdir -p $(dirname $NEXT_AOUT)
	CURL_OPTS="-L -v"
	curl $CURL_OPTS -o $NEXT_AOUT https://github.com/ramalhais/linux/releases/latest/download/aout
	curl $CURL_OPTS -o $NEXT_MACHO https://github.com/ramalhais/linux/releases/latest/download/macho
	curl $CURL_OPTS -o $NEXT_DISKLABEL https://github.com/ramalhais/linux/releases/latest/download/next-disklabel
	chmod +x $NEXT_AOUT
	chmod +x $NEXT_MACHO
	chmod +x $NEXT_DISKLABEL
fi

BOOT_FILE=$OBJDIR/netbsd-boot-next
$NEXT_AOUT $BOOTDIR/boot.raw $BOOT_FILE.aout 0x${LOAD_ADDR}
$NEXT_MACHO $BOOTDIR/boot.raw $BOOT_FILE.macho 0x${LOAD_ADDR}

if [ "$1" == "install" ]; then
	if [ "$2" != "" ]; then
		BOOT_FORMAT=$2

		if [ "$3" != "" ]; then
			DISK="$3"
		fi
	fi
	$NEXT_DISKLABEL "$DISK" -b $BOOT_FILE.$BOOT_FORMAT
fi
