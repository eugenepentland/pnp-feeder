import sys
import subprocess
from pymodbus.client import ModbusSerialClient
from pymodbus.exceptions import ModbusException
import time

def generate_crc16_append(data: list) -> list:
    """
    Compute the Modbus CRC16 checksum for the given data and append the CRC to the data list.

    Args:
        data (list): The input data as a list of integers (each 0-255).

    Returns:
        list: The data list with the CRC16 appended as two separate bytes (low byte first).
    """
    crc = 0xFFFF  # Initialize CRC to 0xFFFF

    for byte in data:
        crc ^= byte  # XOR byte with lower byte of CRC
        for _ in range(8):  # Process each bit
            lsb = crc & 0x0001  # Extract least significant bit
            crc >>= 1  # Shift CRC right by 1
            if lsb:
                crc ^= 0xA001  # XOR with polynomial if LSB was set

    # Mask CRC to 16 bits
    crc &= 0xFFFF

    # Split CRC into low and high bytes
    crc_low = crc & 0xFF
    crc_high = (crc >> 8) & 0xFF

    # Append CRC bytes to the data list (Low byte first)
    data.append(crc_high)
    data.append(crc_low)
    

    return data

import subprocess
import os

def execute_picotool_commands():
    """
    Execute the specified picotool commands to load firmware, reboot the device, and print the main.uf2 file size.
    """
    uf2_file = "zig-out/firmware/main.uf2"
    
    # Check if the file exists and print its size in KB
    if os.path.exists(uf2_file):
        file_size_kb = os.path.getsize(uf2_file) / 1024
        print(f"File size of {uf2_file}: {file_size_kb:.2f} KB")
    else:
        print(f"File {uf2_file} not found.")
        return
    
    # Commands to load firmware and reboot the device
    commands = [
        ["sudo", "picotool", "load", uf2_file],
        ["sudo", "picotool", "reboot", "-F"]
    ]

    for cmd in commands:
        try:
            print(f"Executing command: {' '.join(cmd)}")
            result = subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            print(f"Command Output:\n{result.stdout}")
            if result.stderr:
                print(f"Command Error Output:\n{result.stderr}")
        except subprocess.CalledProcessError as e:
            print(f"An error occurred while executing {' '.join(cmd)}:")
            print(f"Return Code: {e.returncode}")
            print(f"Output: {e.output}")
            print(f"Error Output: {e.stderr}")
            sys.exit(1)  # Exit the script if a command fails

def main():
    # Set up the Modbus RTU client
    client = ModbusSerialClient(
        port='COM9',  # Replace with your serial port
        baudrate=115200,
        parity='N',  # None parity
        stopbits=1,
        bytesize=8,
        timeout=1
    )

    # Attempt to connect to the Modbus client
    if client.connect():
        try:
            # Prepare your data
            data = [0, 125]  # Example data: [0, 125]

            # Compute CRC16 and append to data
            data_with_crc = generate_crc16_append(data.copy())  # Use a copy to preserve original data
            print(f"Data to send (with CRC): {[f'0x{byte:02X}' for byte in data_with_crc]}")

            # Convert the data list to bytes for transmission
            payload = bytes(data_with_crc)

            # Send the data
            # Note: pymodbus does not have a generic send method. You need to use specific Modbus functions.
            # For example, to write registers or coils. Below is an example of writing multiple coils.

            # Example: Writing to coils starting at address 0x00
            # Adjust the function and parameters according to your specific Modbus device and requirements
            client.send(data_with_crc)

        except ModbusException as e:
            print(f"Modbus communication error: {e}")
            sys.exit(1)

        finally:
            # Close the Modbus connection
            client.close()

    #time.sleep(1)
    # Execute the picotool commands after successful Modbus communication
    #execute_picotool_commands()

if __name__ == "__main__":
    main()
