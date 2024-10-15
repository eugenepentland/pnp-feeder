import serial
import time
import sys

# Function to open the serial port
def open_serial_port(port, baudrate):
    """
    Attempts to open the specified serial port with the given baudrate.
    Retries every 2 seconds if the connection fails.

    Args:
        port (str): The serial port to connect to (e.g., 'COM4' or '/dev/ttyUSB0').
        baudrate (int): The baud rate for the serial communication.

    Returns:
        serial.Serial: An instance of the opened serial port.
    """
    while True:
        try:
            ser = serial.Serial(
                port,
                baudrate,
                timeout=1,
                write_timeout=1,      # Prevent write from blocking indefinitely
                rtscts=False,         # Disable RTS/CTS flow control
                dsrdtr=False,         # Disable DSR/DTR flow control
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE,
                bytesize=serial.EIGHTBITS
            )
            print(f"Connected to {port} at {baudrate} baud.")
            return ser
        except serial.SerialException as e:
            print(f"Failed to connect to {port}: {e}")
            print("Retrying in 2 seconds...")
            time.sleep(2)

# Function to communicate with serial: send "hello" every 2 seconds with retry
def communicate_with_serial(ser):
    """
    Continuously sends the string "hello" to the serial device every 2 seconds.
    Implements a retry mechanism in case of transmission failures.

    Args:
        ser (serial.Serial): The opened serial port.
    """
    try:
        while True:
            try:
                print("Trying to send: hello")
                bytes_written = ser.write(b'hello\n')
                print(f"Sent: hello, bytes written: {bytes_written}")
                
                # Optionally, read any immediate response
                response = ser.readline()
                if response:
                    try:
                        decoded_response = response.decode('utf-8', errors='replace').strip()
                        print(f"Received: {decoded_response}")
                    except UnicodeDecodeError:
                        print(f"Received (raw bytes): {response}")
                else:
                    print("No response received.")
            except serial.SerialTimeoutException as e:
                print(f"Write timeout: {e}")
                print("Attempting to reconnect...")
                ser.close()
                ser = open_serial_port(ser.port, ser.baudrate)
                continue  # Retry sending after reconnection
            except serial.SerialException as e:
                print(f"Error during communication: {e}")
                print("Attempting to reconnect...")
                ser.close()
                ser = open_serial_port(ser.port, ser.baudrate)
                continue  # Retry sending after reconnection
            time.sleep(2)
    except KeyboardInterrupt:
        print("\nCommunication interrupted by user.")
        ser.close()
        sys.exit(0)
    except Exception as e:
        print(f"Unexpected error: {e}")
        ser.close()
        sys.exit(1)

# Gracefully release resources on exit
def cleanup():
    """
    Performs any necessary cleanup before exiting the program.
    """
    print("Exiting program.")

if __name__ == "__main__":
    port = 'COM8'       # Replace with your serial port (e.g., '/dev/ttyUSB0' on Linux)
    baudrate = 115200   # Ensure this matches the baudrate of your USB device

    try:
        ser = open_serial_port(port, baudrate)
        communicate_with_serial(ser)
    except KeyboardInterrupt:
        print("\nInterrupted by user.")
    except Exception as e:
        print(f"An error occurred: {e}")
    finally:
        cleanup()
        try:
            ser.close()
        except:
            pass
        sys.exit(0)
