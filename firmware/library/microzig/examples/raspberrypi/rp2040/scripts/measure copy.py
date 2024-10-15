import cv2
import numpy as np
import math
import glob
import os
import statistics
import matplotlib.pyplot as plt

# Function to calculate the angle between two points
def calculate_angle(hole1, hole2):
    delta_x = hole2[0] - hole1[0]
    delta_y = hole2[1] - hole1[1]
    angle = math.degrees(math.atan2(delta_y, delta_x))
    return angle

# Initial detection on one image to define ROI
initial_image_path = 'captures/angle_150/capture_13.jpg'  # Replace with your image path
image = cv2.imread(initial_image_path)

if image is None:
    print(f"Failed to load the initial image: {initial_image_path}")
    exit()

gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
blurred = cv2.GaussianBlur(gray, (9, 9), 2)
circles = cv2.HoughCircles(
    blurred,
    cv2.HOUGH_GRADIENT,
    dp=1.2,
    minDist=50,
    param1=100,
    param2=30,
    minRadius=8,
    maxRadius=15
)

if circles is not None:
    circles = np.round(circles[0, :]).astype("int")
    circles = sorted(circles, key=lambda x: x[0])  # Sort by x-coordinate

    if len(circles) >= 2:
        hole1 = circles[0]  # First circle
        hole2 = circles[1]  # Second circle

        print(f"Initial Detection:")
        print(f"Hole 1: X={hole1[0]}, Y={hole1[1]}, Diameter={hole1[2]*2}")
        print(f"Hole 2: X={hole2[0]}, Y={hole2[1]}, Diameter={hole2[2]*2}")

        # Define ROI with buffer
        buffer = 30  # pixels
        min_x = min(hole1[0], hole2[0]) - buffer
        min_y = min(hole1[1], hole2[1]) - buffer
        max_x = max(hole1[0] + hole1[2], hole2[0] + hole2[2]) + buffer
        max_y = max(hole1[1] + hole1[2], hole2[1] + hole2[2]) + buffer

        # Ensure ROI is within image boundaries
        height, width = image.shape[:2]
        min_x = max(min_x, 0)
        min_y = max(min_y, 0)
        max_x = min(max_x, width)
        max_y = min(max_y, height)
        roi_width = max_x - min_x
        roi_height = max_y - min_y

        print(f"Defined ROI: X={min_x}, Y={min_y}, Width={roi_width}, Height={roi_height}")

        # Optional: Visualize the ROI on the initial image
        visualize_initial_roi = False  # Set to True to visualize
        if visualize_initial_roi:
            roi_visual = image.copy()
            cv2.rectangle(roi_visual, (min_x, min_y), (max_x, max_y), (255, 0, 0), 2)
            cv2.imshow("Initial ROI", roi_visual)
            cv2.waitKey(0)
            cv2.destroyAllWindows()
    else:
        print("Initial image: Less than two circles detected.")
        exit()
else:
    print("Initial image: No circles detected. Please check the image and detection parameters.")
    exit()

# Initialize list to store angles
angles = []

# Path to folder containing images
folder_path = 'captures/angle_150/'  # Replace with your folder path
image_files = glob.glob(os.path.join(folder_path, '*.jpg'))

# Optional: To visualize a few processed images
visualize = False  # Set to True to see visualizations for each image

for idx, image_file in enumerate(image_files):
    # Load the image
    image = cv2.imread(image_file)

    if image is None:
        print(f"Failed to load {image_file}")
        continue

    # Crop the image to the region of interest (ROI)
    roi = image[min_y:min_y + roi_height, min_x:min_x + roi_width]

    # Convert to grayscale
    gray = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY)

    # Apply a Gaussian blur to smooth the image and improve circle detection
    blurred = cv2.GaussianBlur(gray, (9, 9), 2)

    # Detect circles in the cropped image with adjusted parameters
    circles = cv2.HoughCircles(
        blurred,
        cv2.HOUGH_GRADIENT,
        dp=1.2,
        minDist=50,
        param1=80,  # Lowered from 100 to make edge detection more sensitive
        param2=20,  # Lowered from 30 to make circle center detection more lenient
        minRadius=8,
        maxRadius=15
    )

    if circles is not None:
        circles = np.round(circles[0, :]).astype("int")
        circles = sorted(circles, key=lambda x: x[0])  # Sort by x-coordinate

        if len(circles) >= 2:
            hole1 = circles[0]
            hole2 = circles[1]

            # Offset coordinates back to the full image
            hole1_x = hole1[0] + min_x
            hole1_y = hole1[1] + min_y
            hole2_x = hole2[0] + min_x
            hole2_y = hole2[1] + min_y

            # Print the positions and diameters of the detected holes
            print(f"{os.path.basename(image_file)}:")
            print(f"  Hole 1: X={hole1_x}, Y={hole1_y}, Diameter={hole1[2]*2}")
            print(f"  Hole 2: X={hole2_x}, Y={hole2_y}, Diameter={hole2[2]*2}")

            # Calculate the angle between the two holes
            angle = calculate_angle((hole1_x, hole1_y), (hole2_x, hole2_y))
            angles.append(angle)

            if visualize and idx < 5:  # Visualize first 5 images
                vis_image = image.copy()
                # Draw circles
                cv2.circle(vis_image, (hole1_x, hole1_y), hole1[2], (0, 255, 0), 2)
                cv2.circle(vis_image, (hole2_x, hole2_y), hole2[2], (0, 255, 0), 2)
                # Draw centers
                cv2.circle(vis_image, (hole1_x, hole1_y), 2, (0, 0, 255), 3)
                cv2.circle(vis_image, (hole2_x, hole2_y), 2, (0, 0, 255), 3)
                # Draw line
                cv2.line(vis_image, (hole1_x, hole1_y), (hole2_x, hole2_y), (255, 0, 0), 2)
                # Display
                cv2.imshow(f"Detected Circles - {os.path.basename(image_file)}", vis_image)
                cv2.waitKey(0)
                cv2.destroyAllWindows()
        else:
            print(f"  {os.path.basename(image_file)}: Insufficient circles detected (found {len(circles)}).")
    else:
        print(f"  {os.path.basename(image_file)}: No circles detected.")

# Statistical analysis on the angles
if angles:
    mean_angle = statistics.mean(angles)
    std_dev_angle = statistics.stdev(angles)

    # Print out the results
    print(f"\nProcessed {len(angles)} images successfully.")
    print(f"Mean Angle: {mean_angle:.2f} degrees")
    print(f"Standard Deviation: {std_dev_angle:.2f} degrees")

    # Display a histogram of the angles using matplotlib
    plt.figure(figsize=(10, 6))
    plt.hist(angles, bins=10, color='skyblue', edgecolor='black')
    plt.title('Histogram of Measured Servo Angles')
    plt.xlabel('Angle (degrees)')
    plt.ylabel('Frequency')
    plt.grid(True)
    plt.show()
else:
    print("No valid angles were found.")
