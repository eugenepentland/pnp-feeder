#!/usr/bin/env python3

import argparse
import os
import shutil
import sys
import platform
import psutil

def find_rpi_rp2_mount_point():
    """
    Scans all mounted disk partitions to find the one named 'RPI-RP2'.

    Returns:
        The mount point path if found, else None.
    """
    for partition in psutil.disk_partitions(all=False):
        # On Windows, partition.device is like 'E:\\'
        # On macOS/Linux, partition.mountpoint is the path
        try:
            if platform.system() == 'Windows':
                # On Windows, use the volume name
                import ctypes
                volume_name_buffer = ctypes.create_unicode_buffer(1024)
                ctypes.windll.kernel32.GetVolumeInformationW(
                    ctypes.c_wchar_p(partition.device),
                    volume_name_buffer,
                    ctypes.sizeof(volume_name_buffer),
                    None,
                    None,
                    None,
                    None,
                    0
                )
                volume_name = volume_name_buffer.value
                if volume_name.upper() == 'RPI-RP2':
                    return partition.mountpoint
            else:
                # On Unix-like systems, use the mountpoint basename
                volume_label = os.path.basename(partition.mountpoint)
                if volume_label.upper() == 'RPI-RP2':
                    return partition.mountpoint
        except Exception as e:
            # Skip partitions that cause errors
            continue
    return None

def copy_file_to_device(file_path, device_path):
    """
    Copies the specified file to the root of the USB device.

    Args:
        file_path: Path to the source file.
        device_path: Mount point of the target USB device.
    """
    try:
        if not os.path.isfile(file_path):
            print(f"Error: The file '{file_path}' does not exist or is not a file.")
            sys.exit(1)
        
        filename = os.path.basename(file_path)
        destination = os.path.join(device_path, filename)

        print(f"Copying '{file_path}' to '{destination}'...")
        shutil.copy2(file_path, destination)
        print("File copied successfully.")
    except PermissionError:
        print("Error: Permission denied. Try running the script with elevated privileges.")
        sys.exit(1)
    except Exception as e:
        print(f"Error: Failed to copy the file. {e}")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description="Copy a file to the 'RPI-RP2' USB device.")
    parser.add_argument('filename', help='Path to the file to be copied.')

    args = parser.parse_args()
    file_path = args.filename

    if not os.path.isfile(file_path):
        print(f"Error: The file '{file_path}' does not exist.")
        sys.exit(1)

    device_mount = find_rpi_rp2_mount_point()

    if device_mount:
        print(f"Found 'RPI-RP2' device at '{device_mount}'.")
        copy_file_to_device(file_path, device_mount)
    else:
        print("Error: No USB device named 'RPI-RP2' found.")
        sys.exit(1)

if __name__ == '__main__':
    # Check if psutil is installed
    try:
        import psutil
    except ImportError:
        print("Error: The 'psutil' library is required but not installed.")
        print("You can install it using 'pip install psutil'")
        sys.exit(1)

    main()
