import serial
import time
import os
import cv2

# Create directories for storing captures at different angles
capture_dir_90 = 'captures/angle_90'
capture_dir_20 = 'captures/angle_20'
os.makedirs(capture_dir_90, exist_ok=True)
os.makedirs(capture_dir_20, exist_ok=True)

# Set up the serial connection
ser = serial.Serial(
    port='COM4',  # Replace with your serial port
    baudrate=115200,
    parity=serial.PARITY_NONE,  # None parity
    stopbits=serial.STOPBITS_ONE,
    bytesize=serial.EIGHTBITS,
    timeout=1
)

# Open the connection if it's not already open
if not ser.is_open:
    ser.open()

# Initialize the camera
camera = cv2.VideoCapture(0)

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

def set_servo_angle(angle, delay_ms):
    address = 0
    function_id = 102
    data = [address, function_id, angle, 0, 0]  # Example data
    return bytearray(generate_crc16_append(data))

def capture_image(angle):
    # Capture image with the camera
    if not camera.isOpened():
        print("Could not open camera")
        return

    ret, frame = camera.read()
    
    if ret:
        folder = f'captures/angle_{angle}'
        os.makedirs(folder, exist_ok=True)
        file_count = len(os.listdir(folder))
        file_name = f'{folder}/capture_{file_count + 1}.jpg'
        
        # Save the captured image to a file
        cv2.imwrite(file_name, frame)
        print(f"Captured image saved as {file_name}")
    else:
        print("Failed to capture image")

while True:
    for i in [150, 90, 20]:
        data_bytes = set_servo_angle(i, 0)
        ser.write(data_bytes)
        time.sleep(0.5)

        if i != 140:
            capture_image(i)

ser.close()
camera.release()