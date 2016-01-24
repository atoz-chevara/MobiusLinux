#!/usr/bin/env bash
: '
created by : br0k3ngl255
date 2016:01:01
Many thanks to Oros script and netblue3 tutorial for this
'
########################################################################
#Purpose: automating creation of Debian based distro
#		We'll call it :  Mobius Linux 
#
########################################################################
: '
TODO ==>> optimize the installation for all linux distro
TODO ==>> add custom splash image
TODO ==>> add gui, development and network tools.
'
###Vars ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
INITPATH=$(pwd)
DISTNAME='Mobius'
DATE=$(date +%s)


#####Funcs /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
help() {
	echo -e "Build a custom live Debian Based OS - MobiusLinux.\n
	 $0 [new|rebuild] \n
	 new     : remove $livework if exist and build a new live \n
	 rebuild : keep $livework, clean chroot and build a new live \n
	\n$0 should be run as root \n"
	exit 0
}
verifyTools(){
	#tools=('xorriso' 'debootstrap'  'mksquashfs' 'live-build') #need to check if there will be larger list of tools.
	chkTool=$(updatedb;locate xorriso >> /dev/null;echo $?)
	if [ $chkTool -eq 0 ];then
		echo "all needed tools  are located"
	else
		echo "you need to install xorriso"
		 exit 1986
	fi
	}
cleanChroot(){
	if [ -d $INITPATH/custom_conf ]; then
		cp -r $INITPATH/custom_conf/* chroot/
	fi
	rm -rf chroot/root/.bash_history
	rm -rf chroot/var/log/*
	rm -rf chroot/var/cache/apt/archives/*
	rm -rf chroot/tmp/*
}

sysLinuxChk(){
	if [ ! -f config ]; then
		if [ -f default/config ]; then
			cp default/config config
		else
			echo "$0: ${1:-"config file not found"}" 1>&2
		exit 1
		fi
	fi
	../config

	if [[ ! -d custom_conf && -d default/custom_conf ]]; then
		cp -r default/custom_conf custom_conf
	fi

	if [[ ! -d custom_setup && -d default/custom_setup ]]; then
		cp -r default/custom_setup custom_setup
	fi

	if [[ ! -d other_files && -d default/other_files ]]; then
		cp -r default/other_files other_files
	fi

	if [[ ! -d syslinux || ! -f syslinux/ldlinux.c32 ]]; then
		echo "Downloading syslinux..."
			wget https://www.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.gz
			tar xzf syslinux-*.tar.gz
			mv syslinux-*.tar.gz /tmp
			mkdir -p syslinux
	# if you have efi, change bios to efi64 or efi32
			cp syslinux-*/bios/com32/elflink/ldlinux/ldlinux.c32 syslinux
			cp syslinux-*/bios/com32/hdt/hdt.c32 syslinux
			cp syslinux-*/bios/com32/lib/libcom32.c32 syslinux
			cp syslinux-*/bios/com32/libutil/libutil.c32 syslinux
			cp syslinux-*/bios/core/isolinux.bin syslinux
			cp syslinux-*/bios/mbr/isohdpfx.bin syslinux
			cp syslinux-*/bios/com32/menu/vesamenu.c32 syslinux
			chmod 666 syslinux/*
			rm -r syslinux-*
			echo "syslinux setup and ready to GO!"
	fi

	}
###
#Main - _- _- _- _- _- _- _- _- _- _- _- _- _- _- _- _- _- _- _- _- _- _
###
: '
while getopts ":d:n:" OPTIONS:
	do
		case in {@OPTIONS}:
			d) DATE=$OPTARG;;
			n) DISTNAME=$OPTARG;;
			*) echo "NO SUCH OPTION !!!"
		esac
	done 
	'	
verifyTools;sysLinuxChk;

if [ ! "$#" -eq 1 ]; then
	help
fi

if [ "$EUID" -ne 0 ]; then 
	echo -e "\033[31mPlease run as root\033[0m" 1>&2
	exit 1
fi

if [[ ! -d "chroot" || `ls "chroot"` == "" ]]; then
		echo -e "\033[31mchroot is empty 0_0!?\033[0m" 1>&2
		echo "This can happen when you run this script in a encrypted /home/ :-("
		echo "Try to move CustomDebian in an other folder like /tmp/ and try again."
		exit 1
	fi

	if [[ -f $INITPATH/other_files/setup_in_chroot_head.sh && -f $INITPATH/other_files/setup_in_chroot_footer.sh ]]; then
		cat $INITPATH/other_files/setup_in_chroot_head.sh > chroot/setup_in_chroot.sh
		echo -e "apt-get install -y linux-image-${archi}\napt-get install -y live-boot" >> chroot/setup_in_chroot.sh
		echo -e "cp /usr/sbin/update-initramfs.orig.initramfs-tools /usr/sbin/update-initramfs\nupdate-initramfs -u" >> chroot/setup_in_chroot.sh
		if [ -d $INITPATH/custom_setup ]; then
			for f in $INITPATH/custom_setup/*.sh; do
				cat $f >> chroot/setup_in_chroot.sh
			done
		fi
		cat $INITPATH/other_files/setup_in_chroot_footer.sh >> chroot/setup_in_chroot.sh
		chmod +x chroot/setup_in_chroot.sh
		echo -e "\033[31mEnter in chroot\033[0m"
		chroot chroot /setup_in_chroot.sh
		echo -e "\033[31mExit chroot\033[0m"
		rm -fr chroot/setup_in_chroot.sh
		echo "${dist_name}" > chroot/etc/hostname
		clean_chroot
	fi
elif [ "$1" == "rebuild" ]; then
	if [[ -d "$livework" && -d "$livework/chroot" ]]; then
		cd $livework
		clean_chroot
	else
		echo -e "\033[31m$livework/chroot doesn't exist!\033[0m" 1>&2
		exit 1
	fi
else
	help
fi

mkdir -p binary/{live,isolinux}
#cp chroot/boot/vmlinuz-3.2.0-4-${archi} binary/live/vmlinuz
cp $(ls chroot/boot/vmlinuz* |sort --version-sort -f|tail -n1) binary/live/vmlinuz
#cp chroot/boot/initrd.img-3.2.0-4-${archi} binary/live/initrd
cp $(ls chroot/boot/initrd* |sort --version-sort -f|tail -n1) binary/live/initrd
#mksquashfs chroot binary/live/filesystem.squashfs -comp xz -e boot
mksquashfs chroot binary/live/filesystem.squashfs -comp xz

cp $INITPATH/syslinux/*.c32 binary/isolinux
cp $INITPATH/syslinux/*.bin binary/isolinux

cp $INITPATH/other_files/splash.png binary/isolinux/

echo "default vesamenu.c32
prompt 0
MENU background splash.png
MENU title Boot Menu
MENU COLOR screen       37;40   #80ffffff #00000000 std
MENU COLOR border       30;44   #40ffffff #a0000000 std
MENU COLOR title        1;36;44 #ffffffff #a0000000 std
MENU COLOR sel          7;37;40 #e0ffffff #20ffffff all
MENU COLOR unsel        37;44   #50ffffff #a0000000 std
MENU COLOR help         37;40   #c0ffffff #a0000000 std
MENU COLOR timeout_msg  37;40   #80ffffff #00000000 std
MENU COLOR timeout      1;37;40 #c0ffffff #00000000 std
MENU COLOR msg07        37;40   #90ffffff #a0000000 std
MENU COLOR tabmsg       31;40   #ffDEDEDE #00000000 std
MENU HIDDEN
MENU HIDDENROW 8
MENU WIDTH 78
MENU MARGIN 15
MENU ROWS 5
MENU VSHIFT 7
MENU TABMSGROW 11
MENU CMDLINEROW 11
MENU HELPMSGROW 16
MENU HELPMSGENDROW 29

timeout 50

label live-${archi}-ram
	menu label ^${dist_name} RAM (${archi})" > binary/isolinux/isolinux.cfg
if [ "${boot_default}" == "ram" ]; then
	echo "	menu default" >> binary/isolinux/isolinux.cfg
fi
echo "	linux /live/vmlinuz apm=power-off boot=live live-media-path=/live/ toram=filesystem.squashfs
	append initrd=/live/initrd boot=live quiet

label live-${archi}
	menu label ^${dist_name} (${archi})" >> binary/isolinux/isolinux.cfg
if [ "${boot_default}" == "" ]; then
	echo "	menu default" >> binary/isolinux/isolinux.cfg
fi
echo "	linux /live/vmlinuz
	append initrd=/live/initrd boot=live quiet

label live-${archi}-failsafe
	menu label ^${dist_name} (${archi} failsafe)" >> binary/isolinux/isolinux.cfg
if [ "${boot_default}" == "failsafe" ]; then
	echo "	menu default" >> binary/isolinux/isolinux.cfg
fi
echo "	linux /live/vmlinuz
	append initrd=/live/initrd boot=live config memtest noapic noapm nodma nomce nolapic nomodeset nosmp nosplash vga=normal

endtext
" >> binary/isolinux/isolinux.cfg

xorriso -as mkisofs -r -J -joliet-long -l -cache-inodes -isohybrid-mbr $INITPATH/syslinux/isohdpfx.bin -partition_offset 16 -A "${dist_name}"  -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ${iso_name} binary

echo "End"
date
last=`date +%s`
count=$(($last - $now))
min=$((count/60))
sec=$((count%60))
echo "Time : ${min}m ${sec}s"
if [ -f ${iso_name} ] ; then
	echo "ISO build in $livework/${iso_name}"
else
	echo -e "\033[31mError, $livework/${iso_name} not build :-(\033[0m" 1>&2
	exit 1
fi
