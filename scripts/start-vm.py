#!/usr/bin/env python

import argparse
import errno
import pathlib
import os
import subprocess


# glob matching including hidden files
def glob(root, pattern):
    return list(map(lambda p: str(p), pathlib.Path(root).glob(pattern)))


def update_setup_files(storage_image_path):
    if not os.path.isfile(storage_image_path):
        raise OSError(
            errno.EIO, 'There is no storage image at: {}'.format(storage_image_path))

    setup_script_path = os.getenv('QEMU_SETUP_SCRIPT_PATH')
    nixpkgs_override_path = os.getenv('QEMU_NIXPKGS_OVERRIDE_PATH')
    nix_cross_path = os.getenv('QEMU_NIX_CROSS_PATH')
    bootstrap_tools_path = os.getenv('QEMU_BOOTSTRAP_TOOLS_PATH')
    nix_cross_archive_path = os.getenv('QEMU_NIX_CROSS_ARCHIVE')
    bootstrap_tools_output_path = os.getenv('QEMU_BOOTSTRAP_TOOLS_OUTPUT')

    print('Copying setup script to vm storage')
    subprocess.run([
        'virt-copy-in',
        '-a',
        storage_image_path,
        setup_script_path,
        '/usr/bin'
    ])

    print('Cross compiling nix for riscv64')
    subprocess.run([
        'nix',
        'build',
        '--cores', '0',
        '--max-jobs', 'auto',
        '--no-link',
        '-f',
        nix_cross_path,
    ])
    subprocess.run([
        'nix',
        'build',
        '--cores', '0',
        '--max-jobs', 'auto',
        '--no-link',
        '-f',
        bootstrap_tools_path,
        'build'
    ])
    subprocess.run([
        'nix',
        'copy',
        '-f',
        nix_cross_path,
        '--to',
        'file://{}'.format(nix_cross_archive_path)
    ])

    print("Copying cross compiled nix to vm storage")
    nix_cross_dep_paths = None
    with subprocess.Popen(
        ['nix', 'path-info', '-f', nix_cross_path, '-r'],
        stdout=subprocess.PIPE
    ) as p:
        nix_cross_dep_paths = p.stdout \
            .read() \
            .decode() \
            .splitlines()

    if not nix_cross_path:
        raise OSError(
            errno.EIO, 'nix path-info found nothing for the compiled nix derviation at: {}'.format(nix_cross_path))

    subprocess.run([
        'virt-customize',
        '-a',
        storage_image_path,
        '--mkdir',
        '/opt/bootstrap-tools-archive'
    ])
    subprocess.run([
        'virt-customize',
        '-a',
        storage_image_path,
        '--mkdir',
        '/nix/store'
    ])
    subprocess.run([
        'virt-copy-in',
        '-a',
        storage_image_path,
        nix_cross_archive_path,
        '/opt'
    ])
    subprocess.run([
        'virt-copy-in',
        '-a',
        storage_image_path,
        nixpkgs_override_path,
        '/opt'
    ])
    subprocess.run([
        'virt-copy-in',
        '-a',
        storage_image_path,
        *glob(bootstrap_tools_output_path, '*'),
        '/opt/bootstrap-tools-archive'
    ])
    subprocess.run([
        'virt-copy-in',
        '-a',
        storage_image_path,
        *nix_cross_dep_paths,
        '/nix/store'
    ])


if __name__ == "__main__":
    argp = argparse.ArgumentParser()

    argp.add_argument('--smp', default=2, type=int,
                      help="number of vm cores (default: 2)")
    argp.add_argument('-m', '--memory', default="2G", type=str,
                      help="amount of vm memory (default: 2G)")

    argp.add_argument('-pv', '--provision', action="store_true",
                      help="create or recreate vm storage image")
    argp.add_argument('-ss', '--storage-size', default='20g', type=str,
                      help="amount of storage space for the vm (default 20G)")
    argp.add_argument('-ir', '--image-root', type=str,
                      help="root directory of qemu image files (or set QEMU_IMAGE_ROOT)")
    argp.add_argument('-sr', '--storage-root', type=str,

                      help="root directory of qemu storage image (or set QEMU_STORAGE_ROOT or QEMU_IMAGE_ROOT)")
    argp.add_argument('-uf', '--update-setup-files', action="store_true",
                      help="only copy setup files to vm storage")

    args, qemu_args = argp.parse_known_args()

    image_root = args.image_root if args.image_root is not None else os.getenv(
        'QEMU_IMAGE_ROOT')
    if image_root is None:
        raise OSError(
            errno.EIO, 'Please set either the \'--image-root\' argument or the \'QEMU_IMAGE_ROOT\' environment variable to valid path.')
    storage_root = args.storage_root if args.storage_root is not None else os.getenv(
        'QEMU_STORAGE_ROOT', image_root)

    # find kernel image file
    kernel_image_glob = 'Fedora-Minimal-Rawhide-*.elf'
    kernel_image_path = glob(image_root, kernel_image_glob)[0]
    if kernel_image_path is None:
        raise OSError(errno.EIO, 'Cannot match fedora kernel image with the glob pattern: {}'.format(
            kernel_image_glob))

    # find rootfs image file
    rootfs_file_glob = 'Fedora-Minimal-Rawhide-*-sda.raw'
    rootfs_path = glob(image_root, rootfs_file_glob)[0]
    if rootfs_path is None:
        raise OSError(errno.EIO, 'Cannot match fedora base image with the glob pattern: {}'.format(
            rootfs_file_glob))
    rootfs_file_name = os.path.basename(rootfs_path)

    # generate vm storage image if it does not exist
    expanded_image_file_name = '{}.expanded.raw'.format(
        os.path.basename(rootfs_path).split('.raw')[0])
    storage_image_path = os.path.join(storage_root, expanded_image_file_name)

    if args.provision:
        subprocess.run([
            'truncate',
            '-r',
            rootfs_path,
            storage_image_path
        ])

        subprocess.run([
            'truncate',
            '-s',
            args.storage_size,
            storage_image_path
        ])

        subprocess.run([
            'qemu-img',
            'create',
            '-f',
            'raw',
            '-F',
            'raw',
            '-b',
            rootfs_path,
            storage_image_path
        ])
        subprocess.run([
            'virt-resize',
            '-v',
            '-x',
            '--expand',
            '/dev/sda4',
            rootfs_path,
            storage_image_path
        ])
        subprocess.run([
            'virt-filesystems',
            '--long',
            '-h',
            '--all',
            '-a',
            storage_image_path
        ])
        subprocess.run([
            'virt-df',
            '-h',
            '-a',
            storage_image_path
        ])

        update_setup_files(storage_image_path)
        print('Successfully provisioned storage image')
        exit(0)

    if args.update_setup_files:
        update_setup_files(storage_image_path)
        print('Successfully updated vm setup files')
        exit(0)

    if not os.path.isfile(storage_image_path):
        raise OSError(
            errno.EIO, 'There is no storage image at: {}'.format(storage_image_path))

    subprocess.run([
        'qemu-system-riscv64',
        '-nographic',
        '-machine', 'virt',
        '-smp', str(args.smp),
        '-m', str(args.memory),
        '-kernel', kernel_image_path,
        '-bios', 'none',
        '-object', 'rng-random,filename=/dev/urandom,id=rng0',
        '-device', 'virtio-rng-device,rng=rng0',
        '-device', 'virtio-blk-device,drive=hd0',
        '-drive', 'file={},format=raw,id=hd0'.format(storage_image_path),
        '-device', 'virtio-net-device,netdev=usernet',
        '-netdev', 'user,id=usernet,hostfwd=tcp::10000-:22'
    ] + qemu_args)
