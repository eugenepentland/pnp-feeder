import serial
import time

def establish_serial_connection(port='COM8', baudrate=115200, timeout=2):
    """Attempt to establish a serial connection."""
    while True:
        try:
            ser = serial.Serial(port, baudrate, timeout=timeout)
            print(f"Connected to {port} at {baudrate} baud.")
            return ser
        except serial.SerialException as e:
            print(f"Connection failed: {e}. Retrying in 2 seconds...")
            time.sleep(2)

def main():
    ser = establish_serial_connection()

    try:
        while True:
            try:
                val = input("Enter the string you want to send (or 'exit' to quit): ")

                if val.lower() == 'exit':
                    print("Exiting the program.")
                    break

                # Encode the string as bytes using UTF-8 encoding
                data_bytes = val.encode('utf-8')

                # Send the data over serial
                ser.write(data_bytes)
                ser.flush()  # Ensure data is sent immediately

                print(f"Sent: {val}")

            except serial.SerialException as e:
                print(f"Connection lost: {e}. Attempting to reconnect...")
                ser.close()
                ser = establish_serial_connection()

    except KeyboardInterrupt:
        print("\nProcess interrupted by user. Exiting...")

    finally:
        ser.close()
        print("Serial connection closed.")

if __name__ == "__main__":
    main()
