import serial

# Open the serial port
ser = serial.Serial('COM7', 115200, timeout=1)  # Change COM3 to your correct port
print("serial interface conncted")
# Send data
#ser.write(b'Hello, UART\n')

# Read response
while True:
    response = ser.readline()
    if response:
        decoded_response = response.decode('utf-8', errors='replace').strip()
        print(f"Received: {decoded_response}")

