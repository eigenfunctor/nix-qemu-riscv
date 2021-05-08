#!/bin/env python

import argparse
import errno
import glob
import os
import subprocess

if __name__ == "__main__":
    argp = argparse.ArgumentParser();

    argp.add_argument('--smp', default=4, type=int, help="number of vm cores (default: 4)")
    argp.add_argument('-m', '--memory', default="8G", type=str, help="amount of vm memory (default: 8G)")
    argp.add_argument('-ss', '--storage-size', default='20g', type=str, help="amount of storage space for the vm (default 20G)")
    argp.add_argument('-ir', '--image-root', type=str, help="root directory of qemu image files (or set QEMU_IMAGE_ROOT)")
    argp.add_argument('-sr', '--storage-root', type=str, help="root directory of qemu storage image (or set QEMU_STORAGE_ROOT or QEMU_IMAGE_ROOT)")
    args, qemu_args = argp.parse_known_args()

    image_root = args.image_root if args.image_root is not None else os.getenv('QEMU_IMAGE_ROOT');
    if image_root is None:
        raise OSError(errno.EIO, 'Please set either the \'--image-root\' argument or the \'QEMU_IMAGE_ROOT\' environment variable to valid path.')
    storage_root = args.storage_root if args.storage_root is not None else os.getenv('QEMU_STORAGE_ROOT', image_root)

    # find kernel image file
    kernel_image_glob = os.path.join(image_root, 'Fedora-Minimal-Rawhide-*.elf')
    kernel_image_path = glob.glob(kernel_image_glob)[0]
    if kernel_image_path is None:
        raise OSError(errno.EIO, 'Cannot match fedora kernel image with the glob pattern: {}'.format(kernel_image_glob))

    # find rootfs image file
    rootfs_file_glob = os.path.join(image_root, 'Fedora-Minimal-Rawhide-*-sda.raw')
    rootfs_path = glob.glob(rootfs_file_glob)[0]
    if rootfs_path is None:
        raise OSError(errno.EIO, 'Cannot match fedora base image with the glob pattern: {}'.format(rootfs_file_glob))
    rootfs_file_name = os.path.basename(rootfs_path)

    # generate vm storage image if it does not exist
    expanded_file_name = '{}.expanded.raw'.format(os.path.basename(rootfs_path).split('.raw')[0]) 
    expanded_path = os.path.join(storage_root, expanded_file_name)
    if not os.path.isfile(expanded_path):
        subprocess.run([
            'truncate',
            '-r',
            '{}'.format(rootfs_path),
            '{}'.format(expanded_path)
        ])

        subprocess.run([
            'truncate',
            '-s',
            '{}'.format(args.storage_size),
            '{}'.format(expanded_path)
        ])

        subprocess.run([
            'qemu-img',
            'create',
            '-f',
            'raw',
            '-F',
            'raw',
            '-b',
            '{}'.format(rootfs_path),
            '{}'.format(expanded_path)
        ])
        subprocess.run([
            'virt-resize',
            '-v',
            '-x',
            '--expand',
            '/dev/sda4',
            '{}'.format(rootfs_path),
            '{}'.format(expanded_path)
        ])
        subprocess.run([
            'virt-filesystems',
            '--long',
            '-h',
            '--all',
            '-a',
            '{}'.format(expanded_path)
        ])
        subprocess.run([
            'virt-df',
            '-h',
            '-a',
            '{}'.format(expanded_path)
        ])
        print('')

    subprocess.run([
        'qemu-system-riscv64',
        '-nographic',
        '-machine', 'virt',
        '-smp', '{}'.format(args.smp),
        '-m', '{}'.format(args.memory),
        '-kernel', kernel_image_path,
        '-bios', 'none',
        '-object', 'rng-random,filename=/dev/urandom,id=rng0',
        '-device', 'virtio-rng-device,rng=rng0',
        '-device', 'virtio-blk-device,drive=hd0',
        '-drive', 'file={},format=raw,id=hd0'.format(expanded_path),
        '-device', 'virtio-net-device,netdev=usernet',
        '-netdev', 'user,id=usernet,hostfwd=tcp::10000-:22'
    ] + qemu_args)
