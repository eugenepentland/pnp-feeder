import cv2
import numpy as np
import os
import matplotlib.pyplot as plt
from collections import Counter

# Helper function to find circles
def find_circles(image, dp=1.2, min_dist=50, param1=50, param2=30, min_radius=15, max_radius=50):
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    blurred = cv2.GaussianBlur(gray, (9, 9), 2, 2)
    circles = cv2.HoughCircles(blurred, cv2.HOUGH_GRADIENT, dp, min_dist, param1=param1, param2=param2, minRadius=min_radius, maxRadius=max_radius)
    if circles is not None:
        circles = np.uint16(np.around(circles))
    return circles

# Parameters
captures_folder = 'captures/angle_85'
reference_x = 175
reference_y = 255
tolerance_px = 5  # Tolerance for matching coordinates
min_radius = 20  # Replace with your desired minimum radius
max_radius = 30  # Replace with your desired maximum radius
pixel_to_mm = 1.4 / (2 * 27)  # Conversion factor from pixels to mm (radius of 27 px corresponds to 1.4 mm diameter)

# Collect x-coordinates and radii of matching circles
x_coordinates = []
radii = []

# Process each image in the folder
for image_file in sorted(os.listdir(captures_folder)):
    if image_file.endswith(('.png', '.jpg', '.jpeg')):
        image_path = os.path.join(captures_folder, image_file)
        image = cv2.imread(image_path)

        if image is None:
            print(f"Error: Unable to load image {image_path}.")
            continue

        # Find circles in the image
        circles = find_circles(image, min_radius=min_radius, max_radius=max_radius)

        if circles is not None:
            for circle in circles[0, :]:
                x, y, r = circle
                if abs(x - reference_x) <= tolerance_px and abs(y - reference_y) <= tolerance_px:
                    x_coordinates.append(x)
                    radii.append(r)
                    # Draw the circle and its center on the image
                    cv2.circle(image, (x, y), r, (0, 255, 0), 2)
                    cv2.circle(image, (x, y), 2, (0, 0, 255), 3)
        else:
            print(f"No circles found in image: {image_file}")

# Plot the histogram of x-coordinate deviations in mm
if x_coordinates:
    x_coordinates_mm = [x * pixel_to_mm for x in x_coordinates]
    mean_x = np.mean(x_coordinates_mm)
    x_coordinates_mm_centered = [x - mean_x for x in x_coordinates_mm]

    plt.hist(x_coordinates_mm_centered, bins=10, color='b', alpha=0.7)
    plt.xlabel('X Coordinate Deviation (mm)')
    plt.ylabel('Frequency')
    plt.title('Histogram of X Coordinate Deviations (Centered at Mean)')
    plt.grid(True)
    plt.show()

    # Plot the time series of x-coordinate deviations
    plt.plot(range(len(x_coordinates_mm_centered)), x_coordinates_mm_centered, marker='o', linestyle='-')
    plt.xlabel('Image Index')
    plt.ylabel('X Coordinate Deviation (mm)')
    plt.title('Time Series of X Coordinate Deviations (Centered at Mean)')
    plt.grid(True)
    plt.show()

radii = None
# Plot the radius counts
if radii:
    # Count occurrences of each radius
    radius_counter = Counter(radii)

    # Plot bar chart for radii
    plt.bar(radius_counter.keys(), radius_counter.values(), color='g')
    plt.xlabel('Radius (px)')
    plt.ylabel('Count')
    plt.title('Count of Radii of Detected Circles')
    plt.grid(True)
    plt.show()
else:
    print("No matching circles found in any image.")
