import serial

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
    
    # Append CRC bytes to the data list
    data.append(crc_high)
    data.append(crc_low)  # Append low byte first
      # Append high byte second
    
    return data


# Set up the serial connection
ser = serial.Serial(
    port='/dev/ttyACM1',  # Replace with your serial port
    baudrate=115200,
    parity=serial.PARITY_NONE,  # None parity
    stopbits=serial.STOPBITS_ONE,
    bytesize=serial.EIGHTBITS,
    timeout=1
)

# Open the connection if it's not already open
if not ser.is_open:
    ser.open()

string = "Hello world"
address = 0
function_id = 101
args = 50
data = [address, function_id, args]  # Example data

# Append CRC16 to data
data_bytes = bytearray(generate_crc16_append(data))

while True:
    # Send the data
    val = int(input("Enter the LED level from 0 to 100: "))
    data[2] = val
    data_bytes = bytearray(generate_crc16_append(data))
    ser.write(data_bytes)
    # Print sent data
    #print("Sent data:", data)

    # Read response (up to 64 bytes)
    #val = input("press enter or type 'E' to exit: ")
    #if val == "E":
    #    break

# Close the serial connection
ser.close()
