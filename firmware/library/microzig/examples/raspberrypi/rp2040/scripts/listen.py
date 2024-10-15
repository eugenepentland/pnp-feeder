import cv2
import serial
import time
import os

# Create directories for storing captures at different angles
capture_dir_5 = 'captures/angle_5'
capture_dir_45 = 'captures/angle_45'
os.makedirs(capture_dir_5, exist_ok=True)
os.makedirs(capture_dir_45, exist_ok=True)
camera = cv2.VideoCapture(0)

# Function to capture and save image
def capture_image(angle):
    # Open the first camera (0 usually refers to the default camera)
    
    if not camera.isOpened():
        print("Could not open camera")
        return

    # Read a frame from the camera
    ret, frame = camera.read()
    
    # Check if the frame was captured successfully
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
    
    # Release the camera

# Function to open the serial port
def open_serial_port(port, baudrate):
    while True:
        try:
            ser = serial.Serial(port, baudrate, timeout=1)
            print(f"Connected to {port}")
            return ser
        except serial.SerialException as e:
            print(f"Failed to connect to {port}: {e}")
            print("Retrying in 2 seconds...")
            time.sleep(2)

def listen_to_serial(ser):
    try:
        while True:
            if ser.in_waiting > 0:
                data = ser.readline().decode('utf-8').rstrip()
                print(f"Received: {data}")
                
                # Check if the message contains "Angle: " and extract the angle value
                if data.startswith("Angle: "):
                    try:
                        angle = int(data.split(": ")[1])
                        capture_image(angle)
                    except ValueError:
                        print(f"Invalid angle value received: {data}")
    except serial.SerialException as e:
        print(f"Serial connection lost: {e}")
        ser.close()

if __name__ == "__main__":
    port = 'COM4'
    baudrate = 115200

    while True:
        ser = open_serial_port(port, baudrate)
        listen_to_serial(ser)
