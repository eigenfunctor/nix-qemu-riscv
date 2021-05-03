#!/bin/env python

import argparse
import errno
import os
import subprocess

if __name__ == "__main__":
    argp = argparse.ArgumentParser();

    argp.add_argument('--smp', default=4, type=int, help="number of vm cores")
    argp.add_argument('-m', '--memory', default="8G", type=str, help="amount of vm memory")
    argp.add_argument('-r', '--image-root', type=str, help="root directory of qemu image files")
    args, qemu_args = argp.parse_known_args()

    image_root = args.image_root if args.image_root is not None else os.getenv('QEMU_IMAGE_ROOT');

    if image_root is None:
        raise OSError(errno.EIO, 'Please set either the \'--image-root\' argument or the \'QEMU_IMAGE_ROOT\' environment variable to valid path.')

    subprocess.run([
        'qemu-system-riscv64',
        '-nographic',
        '-machine', 'virt',
        '-smp', '{}'.format(args.smp),
        '-m', '{}'.format(args.memory),
        '-kernel', os.path.join(image_root, 'Fedora-Minimal-Rawhide-20200108.n.0-fw_payload-uboot-qemu-virt-smode.elf'),
        '-bios', 'none',
        '-object', 'rng-random,filename=/dev/urandom,id=rng0',
        '-device', 'virtio-rng-device,rng=rng0',
        '-device', 'virtio-blk-device,drive=hd0',
        '-drive', 'file=' + os.path.join(image_root, 'Fedora-Minimal-Rawhide-20200108.n.0-sda.raw') + ',format=raw,id=hd0',
        '-device', 'virtio-net-device,netdev=usernet',
        '-netdev', 'user,id=usernet,hostfwd=tcp::10000-:22'
    ] + qemu_args)
