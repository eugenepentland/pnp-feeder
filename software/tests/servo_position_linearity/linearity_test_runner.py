import os
import time
import math
import csv
import serial
import cv2
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

import software.tests.servo_position_linearity.messages as messages  # Assuming this is a custom module


# Constants
IMAGE_SAVE_DIR = "measured_images"
SINGLE_IMAGE_FILENAME = os.path.join(IMAGE_SAVE_DIR, "current_view.png")
BLURRED_IMAGE_FILENAME = os.path.join(IMAGE_SAVE_DIR, "blurred_view.png")
GRAY_IMAGE_FILENAME = os.path.join(IMAGE_SAVE_DIR, "gray_view.png")

CSV_FILENAME = "data.csv"
FIELDNAMES = ["x_position_mm", "index"]  # Store x position in mm and index

CIRCLE_DIAMETER_PIXELS = 72  # Diameter in pixels
CIRCLE_DIAMETER_MM = 1.4      # Actual diameter in millimeters (update as needed)
PIXEL_TO_MM_SCALE = CIRCLE_DIAMETER_MM / CIRCLE_DIAMETER_PIXELS  # mm per pixel

# Define the Region of Interest (ROI) as a dictionary
roi = {
    "x_start": None,
    "y_start": None,
    "width": None,
    "height": None
}

def ensure_image_save_dir():
    """Ensure that the image save directory exists."""
    os.makedirs(IMAGE_SAVE_DIR, exist_ok=True)

def write_message(message, ser):
    """Serialize and send a message through the serial port."""
    data = message.serialize()
    ser.write(data)
    _ = ser.read(4)  # Read acknowledgment (if needed)

def detect_and_draw_circle(original_image, cropped_image, roi_x_start, roi_y_start):
    """
    Detect the closest circle to the center of the cropped image and draw it on the original image.
    
    Returns:
        x_position_mm (float): The x position in millimeters.
        processed_image (numpy.ndarray): The image with the detected circle drawn.
        gray (numpy.ndarray): Grayscale image.
        gray_blurred (numpy.ndarray): Blurred grayscale image.
        closest_circle (tuple): Coordinates and radius of the detected circle.
    """
    gray = cv2.cvtColor(cropped_image, cv2.COLOR_BGR2GRAY)
    gray_blurred = cv2.medianBlur(gray, 5)

    # Detect circles using HoughCircles
    circles = cv2.HoughCircles(
        gray_blurred,
        cv2.HOUGH_GRADIENT,
        dp=1,
        minDist=20,
        param1=25,
        param2=20,
        minRadius=36,
        maxRadius=38
    )

    closest_circle = None
    min_distance = float('inf')
    center_x = cropped_image.shape[1] // 2
    center_y = cropped_image.shape[0] // 2

    if circles is not None:
        circles = np.round(circles[0, :]).astype("int")
        for x, y, r in circles:
            distance = math.sqrt((x - center_x)**2 + (y - center_y)**2)
            if distance < min_distance:
                closest_circle = (x, y, r)
                min_distance = distance

        if closest_circle:
            x, y, r = closest_circle
            original_x = roi_x_start + x
            original_y = roi_y_start + y
            cv2.circle(original_image, (original_x, original_y), r, (0, 255, 0), 4)
            # Convert x position to mm
            x_position_mm = original_x * PIXEL_TO_MM_SCALE
            return x_position_mm, original_image, gray, gray_blurred, closest_circle

    return None, original_image, gray, gray_blurred, None

def capture_and_process(camera, is_first_iteration, roi):
    """
    Capture images from the camera, detect circles, and ensure stability of detection.
    
    Returns:
        calculated_x_position (float): The stable x position in millimeters.
        processed_image_for_save (numpy.ndarray): The processed image to save.
        detected_circle (tuple): Coordinates and radius of the detected circle.
    """
    attempts = 0
    max_attempts = 5
    calculated_x_position = None
    processed_image_for_save = None
    detected_circle = None

    while attempts < max_attempts:
        ret, captured_image = camera.read()
        if not ret:
            print(f"Error reading camera (attempt {attempts + 1})")
            attempts += 1
            continue

        image_height, image_width, _ = captured_image.shape

        if is_first_iteration:
            roi["x_start"] = 0
            roi["y_start"] = 0
            roi["width"] = image_width
            roi["height"] = image_height
        else:
            # Validate and adjust ROI within image bounds
            roi["x_start"] = max(0, min(roi["x_start"], image_width - roi["width"]))
            roi["y_start"] = max(0, min(roi["y_start"], image_height - roi["height"]))

        # Crop the image to the ROI
        cropped_image = captured_image[
            roi["y_start"]:roi["y_start"] + roi["height"],
            roi["x_start"]:roi["x_start"] + roi["width"]
        ]

        x_position1, processed_image1, _, _, detected_circle = detect_and_draw_circle(
            captured_image, cropped_image, roi["x_start"], roi["y_start"]
        )

        if detected_circle is not None:
            _, _, cr = detected_circle

            # Update ROI to be centered around the detected circle
            new_roi_width = int(2 * cr * 2)  # 2 times the diameter
            new_roi_height = int(2 * cr * 2)
            cx_absolute = roi["x_start"] + detected_circle[0]
            cy_absolute = roi["y_start"] + detected_circle[1]

            roi["x_start"] = max(0, int(cx_absolute - new_roi_width / 2))
            roi["y_start"] = max(0, int(cy_absolute - new_roi_height / 2))
            roi["width"] = min(new_roi_width, image_width - roi["x_start"])
            roi["height"] = min(new_roi_height, image_height - roi["y_start"])

        if x_position1 is None:
            attempts += 1
            continue

        # Capture the second image for stability check
        ret2, captured_image2 = camera.read()
        if not ret2:
            print("Error reading camera (stability check)")
            return None, None, None

        cropped_image2 = captured_image2[
            roi["y_start"]:roi["y_start"] + roi["height"],
            roi["x_start"]:roi["x_start"] + roi["width"]
        ]
        x_position2, _, _, _, _ = detect_and_draw_circle(
            captured_image2, cropped_image2, roi["x_start"], roi["y_start"]
        )

        if x_position2 is None:
            attempts += 1
            continue

        if abs(x_position1 - x_position2) < 10 * PIXEL_TO_MM_SCALE:  # Adjust threshold based on scale
            calculated_x_position = x_position1
            processed_image_for_save = processed_image1
            break
        else:
            print(f"X positions not consistent ({x_position1:.2f} mm vs {x_position2:.2f} mm), retrying...")
            attempts += 1

    if calculated_x_position is not None and processed_image_for_save is not None:
        cv2.imwrite(SINGLE_IMAGE_FILENAME, processed_image_for_save)
        print(f"Saved current view image to {SINGLE_IMAGE_FILENAME}")

    return calculated_x_position, processed_image_for_save, detected_circle

def plot_aggregated_x_position_stats(data, attempt_count):
    """
    Plot the median and standard deviation of x positions against the index.
    
    Args:
        data (list of dict): Collected data with x_position_mm and index.
        attempt_count (int): The current iteration count for labeling the plot.
    """
    if not data:
        print("No data to plot.")
        return

    df = pd.DataFrame(data)

    # Filter data within the index range [200, 850]
    filtered_df = df[(df['index'] >= 200) & (df['index'] <= 850)]

    if filtered_df.empty:
        print("No data to plot within the index range [200, 850].")
        return

    median_x = filtered_df.groupby('index')['x_position_mm'].median().reset_index()
    median_x = median_x.rename(columns={'x_position_mm': 'median_x_position_mm'})

    std_devs = filtered_df.groupby('index')['x_position_mm'].std().reset_index()
    std_devs = std_devs.rename(columns={'x_position_mm': 'x_position_std_mm'})

    if median_x.empty or std_devs.empty:
        print("No median or standard deviation to plot within the index range [200, 850].")
        return

    fig, axs = plt.subplots(2, 1, figsize=(12, 10))
    fig.suptitle(
        f'X Position Statistics vs Index (Aggregated Across Attempts) - {attempt_count} Attempts',
        fontsize=14
    )

    # Plot median x position
    axs[0].plot(
        median_x['index'],
        median_x['median_x_position_mm'],
        marker='o',
        linestyle='-',
        label='Median X Position',
        color='blue'
    )
    axs[0].set_xlabel('Index')
    axs[0].set_ylabel('X Position (mm)')
    axs[0].grid(True)
    axs[0].legend()

    # Plot standard deviation of x position
    axs[1].plot(
        std_devs['index'],
        std_devs['x_position_std_mm'],
        marker='o',
        linestyle='-',
        color='green'
    )
    axs[1].set_xlabel('Index')
    axs[1].set_ylabel('Standard Deviation of X Position (mm)')
    axs[1].grid(True)

    plt.tight_layout(rect=[0, 0.03, 1, 0.95])  # Adjust layout to make room for suptitle
    plot_filename = f'aggregated_median_std_dev_vs_index_plot_attempt_{attempt_count}.png'
    plt.savefig(plot_filename)
    print(f"Saved plot to {plot_filename}")
    plt.close()

def main():
    """Main function to execute the measurement and plotting process."""
    ensure_image_save_dir()

    # Open serial port
    try:
        ser = serial.Serial(
            port='/dev/ttyACM1',
            baudrate=115200,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            bytesize=serial.EIGHTBITS,
            timeout=5
        )
    except serial.SerialException as e:
        print(f"Error opening serial port: {e}")
        return

    # Open camera
    camera = cv2.VideoCapture(0)
    if not camera.isOpened():
        print("Error: Could not open camera.")
        ser.close()
        return

    # Open CSV file
    with open(CSV_FILENAME, mode="w", newline="") as csv_file:
        csv_writer = csv.DictWriter(csv_file, fieldnames=FIELDNAMES)
        csv_writer.writeheader()
        result_list = []
        iteration_count = 0

        try:
            while True:
                print("Starting new outer loop iteration")
                write_message(messages.rotate_servo(0, 900), ser)
                is_first_iteration = True  # Reset for the new outer loop
                print("Outer loop: is_first_iteration set to True")

                # Reset ROI to trigger full image on first capture
                roi["x_start"] = None
                roi["y_start"] = None
                roi["width"] = None
                roi["height"] = None

                for i in range(900, 275, -5):
                    write_message(messages.rotate_servo(0, i), ser)
                    time.sleep(0.2)

                    detected_x_mm, processed_image, detected_circle = capture_and_process(
                        camera, is_first_iteration, roi
                    )
                    print(
                        f"Main loop: After capture_and_process, detected_x_mm = {detected_x_mm}, "
                        f"is_first_iteration = {is_first_iteration}, "
                        f"ROI = ({roi['x_start']}, {roi['y_start']}, {roi['width']}, {roi['height']}), "
                        f"Circle: {detected_circle}"
                    )

                    if detected_x_mm is not None:
                        row = {
                            "x_position_mm": detected_x_mm,
                            "index": i
                        }
                        csv_writer.writerow(row)
                        result_list.append(row)

                        is_first_iteration = False  # After the first successful detection
                    else:
                        print(f"Failed to detect stable circle for servo position {i}")

                iteration_count += 1
                plot_aggregated_x_position_stats(result_list, iteration_count)
        finally:
            # Release resources
            if camera.isOpened():
                camera.release()
            if ser.is_open:
                ser.close()
            print("Camera and Serial port closed, CSV file saved.")

if __name__ == "__main__":
    main()
