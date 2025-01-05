import serial
import signal
import sys

def signal_handler(sig, frame):
    print("\nCtrl+C detected. Closing serial connection...")
    if ser and ser.is_open:
        ser.close()
    sys.exit(0)

if __name__ == "__main__":
    # Set up signal handler for Ctrl+C
    signal.signal(signal.SIGINT, signal_handler)

    ser = None  # Define `ser` outside the try block for access in the signal handler
    
    try:
        # Connect to the serial port
        ser = serial.Serial(
            port='/dev/ttyACM0',  # Replace with your serial port
            baudrate=115200,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            bytesize=serial.EIGHTBITS,
            timeout=2  # Adjust timeout as needed
        )
        print("Connected to serial port. Reading data...")

        # Continuously read data from the serial port
        while True:
            if ser.in_waiting > 0:  # Check if data is available
                data = ser.read(ser.in_waiting).decode('utf-8', errors='ignore')  # Decode as UTF-8, ignoring errors
                print(data, end='')  # Print the data without adding extra newlines

    except Exception as e:
        print(f"Error: {e}")

    finally:
        # Ensure the serial connection is closed
        if ser and ser.is_open:
            print("Closing serial connection...")
            ser.close()
