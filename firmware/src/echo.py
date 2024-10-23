import serial
import time

def generate_crc16_append(data: list) -> list:
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

def echo_response(content):
    address = 0
    function_id = 125
    data = [address, function_id] + list(content)  # Example data
    return bytearray(generate_crc16_append(data))


import time

while True:
    #i = input("Type what you want to send: ")
    i = "h"
    input_bytes = i.encode('utf-8')
    data_bytes = echo_response([0])
    

    # Start timing using a high-precision timer
    start_time = time.perf_counter()
    
    ser.write(data_bytes)
    print(data_bytes)
    # Await a response
    #bytes = ser.read(len(input_bytes))
    #print(bytes)
    
    # Calculate the time difference using a high-precision timer
    execution_time = time.perf_counter() - start_time
    print(f"Execution time: {execution_time:.10f} seconds. {bytes}")
    time.sleep(0.5)
    

ser.close()