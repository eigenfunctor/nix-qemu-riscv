#!/bin/env python

import argparse
import errno
import glob
import os
import subprocess

def update_setup_files(storage_image_path, opt_root="/opt/qemu-riscv64-setup.d"):
    if not os.path.isfile(storage_image_path):
        raise OSError(errno.EIO, 'There is no storage image at: {}'.format(storage_image_path))

    archive_root = os.getenv('QEMU_ARCHIVE_ROOT')
    setup_script_path = os.getenv('QEMU_SETUP_SCRIPT_PATH')
    bootstrap_tools_path = os.getenv('QEMU_BOOTSTRAP_TOOLS_PATH')
    nix_daemon_service = os.getenv('QEMU_NIX_DAEMON_SERVICE_PATH')

    print('Copying setup script to vm storage')
    subprocess.run([
        'virt-customize',
        '-a',
        '{}'.format(storage_image_path),
        '--mkdir',
        '{}'.format(os.path.join(opt_root, "src")),
    ])
    subprocess.run([
        'virt-copy-in',
        '-a',
        '{}'.format(storage_image_path),
        '{}'.format(setup_script_path),
        '/usr/bin'
    ])

    print("Copying nix-daemon systemd service unit to vm storage")
    subprocess.run([
        'virt-copy-in',
        '-a',
        '{}'.format(storage_image_path),
        '{}'.format(nix_daemon_service),
        '{}'.format("/etc/systemd/system")
    ])

    print("Copying bootstrap-tools nix expression to vm storage")
    subprocess.run([
        'virt-copy-in',
        '-a',
        '{}'.format(storage_image_path),
        '{}'.format(bootstrap_tools_path),
        '{}'.format(os.path.join(opt_root, "src"))
    ])

    print("Cross compiling nix bootstrap tools")
    subprocess.run([
        'nix',
        'build',
        '--cores', '0',
        '--max-jobs', 'auto',
        '--no-link',
        '-f',
        '{}'.format(bootstrap_tools_path),
        'build'
    ])

    print("Copying bootstrap-tools nix archive to vm storage")
    subprocess.run([
        'virt-customize',
        '-a',
        '{}'.format(storage_image_path),
        '--mkdir',
        '{}'.format(os.path.join(opt_root, "archive")),
    ])
    subprocess.run([
        'nix',
        'copy',
        '-f',
        '{}'.format(bootstrap_tools_path),
        '--to',
        'file://{}'.format(os.path.join(archive_root, "bootstrap-tools")),
        'build'
    ])
    subprocess.run([
        'virt-copy-in',
        '-a',
        '{}'.format(storage_image_path),
        '{}'.format(os.path.join(archive_root, "bootstrap-tools")),
        '{}'.format(os.path.join(opt_root, "archive"))
    ])

if __name__ == "__main__":
    argp = argparse.ArgumentParser();

    argp.add_argument('--smp', default=2, type=int, help="number of vm cores (default: 2)")
    argp.add_argument('-m', '--memory', default="8G", type=str, help="amount of vm memory (default: 2G)")
    argp.add_argument('-ss', '--storage-size', default='20g', type=str, help="amount of storage space for the vm (default 20G)")
    argp.add_argument('-ir', '--image-root', type=str, help="root directory of qemu image files (or set QEMU_IMAGE_ROOT)")
    argp.add_argument('-sr', '--storage-root', type=str, help="root directory of qemu storage image (or set QEMU_STORAGE_ROOT or QEMU_IMAGE_ROOT)")
    argp.add_argument('-uf', '--update-setup-files', action="store_true", help="only copy setup files to vm storage")
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
    expanded_image_file_name = '{}.expanded.raw'.format(os.path.basename(rootfs_path).split('.raw')[0]) 
    storage_image_path = os.path.join(storage_root, expanded_image_file_name)
    if not os.path.isfile(storage_image_path):
        subprocess.run([
            'truncate',
            '-r',
            '{}'.format(rootfs_path),
            '{}'.format(storage_image_path)
        ])

        subprocess.run([
            'truncate',
            '-s',
            '{}'.format(args.storage_size),
            '{}'.format(storage_image_path)
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
            '{}'.format(storage_image_path)
        ])
        subprocess.run([
            'virt-resize',
            '-v',
            '-x',
            '--expand',
            '/dev/sda4',
            '{}'.format(rootfs_path),
            '{}'.format(storage_image_path)
        ])
        subprocess.run([
            'virt-filesystems',
            '--long',
            '-h',
            '--all',
            '-a',
            '{}'.format(storage_image_path)
        ])
        subprocess.run([
            'virt-df',
            '-h',
            '-a',
            '{}'.format(storage_image_path)
        ])

        update_setup_files(storage_image_path)

        print('')

    if args.update_setup_files:
      update_setup_files(storage_image_path)
      exit(0)

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
        '-drive', 'file={},format=raw,id=hd0'.format(storage_image_path),
        '-device', 'virtio-net-device,netdev=usernet',
        '-netdev', 'user,id=usernet,hostfwd=tcp::10000-:22'
    ] + qemu_args)
