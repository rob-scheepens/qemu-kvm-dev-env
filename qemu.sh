#!/bin/bash -e

. $(dirname "$0")/config.sh

KERNEL="$KERNEL_BUILD_DIR/arch/x86/boot/bzImage"
if [ ! -f $KERNEL ]; then
	echo "Please make sure the kernel is available as per the configuration"
	exit 1
fi

if [ ! -e initrd ]; then
  echo "
Please create an initrd for the test:

  $ ./mkinitramfs.sh initrd"
  echo 1
fi

set -x

/usr/bin/qemu-system-x86_64 \
	-smp 1 \
	-kernel $KERNEL \
	-initrd $INITRD_PATH \
	-cpu host,hv-crash=on,hv-vpindex=on,hv-relaxed=on,hv-synic=on,hv-stimer=on,hv-runtime=on,hv-time=on,hv-reset=on,hv-time=on,hv-xmm-input=on,hv-tlbflush-ext=on,hv-xmm-output=on,hv-tlbflush=on,hv-ipi=on,hv-frequencies=on,hv-vapic=on,hv-vsm=on \
	-machine q35,kernel-irqchip=split \
	-device intel-iommu,intremap=on,device-iotlb=on \
	-enable-kvm \
	-m 32G \
	-drive file=$GUEST_IMAGE,if=none,id=nvme0,format=qcow2,snapshot=on \
	-device nvme,drive=nvme0,serial=1234 \
	-netdev user,id=n0,hostfwd=tcp::5900-:5900,hostfwd=tcp::$SSH_PORT-:$SSH_PORT,hostfwd=tcp::3389-:3389,hostfwd=tcp::$GUEST_CONSOLE_PORT-:$GUEST_CONSOLE_PORT,hostfwd=tcp::$HOST_TELNET_PORT-:$HOST_TELNET_PORT,hostfwd=tcp::$GDB_PORT-:$GDB_PORT \
	-device e1000,netdev=n0 \
        -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4MB.secboot.fd\
        -drive if=pflash,format=raw,file=/usr/share/OVMF/OVMF_VARS_4MB.secboot.fd \
	-display none \
	-device virtio-serial-pci \
	-chardev stdio,id=c,signal=off,mux=on \
	-mon chardev=c,mode=readline \
	-device virtconsole,chardev=c \
	-device qemu-xhci \
	-append "console=hvc0 kvm_intel.dump_invalid_vmcs=1 nokaslr vfio_iommu_type1.allow_unsafe_interrupts=1 $1 $2" \
	-virtfs local,path=$SHARE_DIR,mount_tag=host,security_model=none \
        -chardev socket,id=chrtpm,path=/tmp/swtpm-sock \
        -tpmdev emulator,id=tpm0,chardev=chrtpm \
        -device tpm-tis,tpmdev=tpm0 \
	-vnc :1 \
        -d guest_errors \
        -D /var/log/qemu-debug.log
