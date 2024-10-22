import cv2
import numpy as np
import os
import matplotlib.pyplot as plt
import re

# Parameters
captures_folder = 'captures'
hole_diameter_mm = 1.5

# Load reference coordinates from file
reference_coordinates_file = "circle_coordinates.txt"
try:
    with open(reference_coordinates_file, "r") as file:
        line = file.readline().strip()
        reference_x, reference_y, _ = map(int, line.split())
        manual_reference_coordinates = (reference_x, reference_y)
except FileNotFoundError:
    print(f"Error: {reference_coordinates_file} not found.")
    exit()

reference_circle_radius = 50  # Radius for masking the search area

# Helper function to find circles
def find_circles(image, dp=1.2, min_dist=50, param1=50, param2=30, min_radius=15, max_radius=17):
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    blurred = cv2.GaussianBlur(gray, (9, 9), 2, 2)
    circles = cv2.HoughCircles(blurred, cv2.HOUGH_GRADIENT, dp, min_dist, param1=param1, param2=param2, minRadius=min_radius, maxRadius=max_radius)
    if circles is not None:
        circles = np.uint16(np.around(circles))
    return circles

# Process each angle folder
for angle_folder in sorted(os.listdir(captures_folder)):
    angle_path = os.path.join(captures_folder, angle_folder)
    if not os.path.isdir(angle_path):
        continue

    image_files = sorted([f for f in os.listdir(angle_path) if f.startswith('capture_') and f.endswith(('.png', '.jpg', '.jpeg'))], key=lambda x: int(re.findall(r'\d+', x)[0]))
    reference_circle = None
    positions = []

    # Always use manual reference coordinates to define the area for circle detection
    reference_x, reference_y = manual_reference_coordinates
    first_image_path = os.path.join(angle_path, image_files[0])
    first_image = cv2.imread(first_image_path)

    # Create a mask to focus on the area around the manual reference coordinates
    mask = np.zeros(first_image.shape[:2], dtype=np.uint8)
    cv2.circle(mask, (reference_x, reference_y), reference_circle_radius, 255, -1)
    masked_image = cv2.bitwise_and(first_image, first_image, mask=mask)

    # Find circles within the masked area
    circles = find_circles(masked_image)
    if circles is not None:
        for circle in circles[0, :]:
            x, y, r = circle
            # Find the circle closest to the manual coordinates
            if abs(x - reference_x) < 10 and abs(y - reference_y) < 10:  # Tolerance to find the closest circle
                reference_circle = (x, y, r)
                hole_diameter_pixels = 2 * r
                # Draw manual reference point in red and reference circle radius in blue
                reference_image = first_image.copy()
                cv2.circle(reference_image, (reference_x, reference_y), reference_circle_radius, (255, 0, 0), 2)  # Blue circle for reference radius
                cv2.circle(reference_image, (x, y), r, (0, 0, 255), 2)  # Red circle for actual detected circle
                cv2.putText(reference_image, f"X: {x}, Y: {y}, Diameter: {2*r}", (x - 50, y - 30), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (169, 169, 169), 2)
                # Save reference image with highlighted manual reference point
                reference_image_path = os.path.join(angle_path, f'reference_image_{angle_folder}.png')
                cv2.imwrite(reference_image_path, reference_image)
                positions.append((x, y))
                break
    else:
        print(f"No circles found in reference image: {first_image_path}")
        continue

    # Use the reference circle position as baseline for all other images
    if reference_circle is not None:
        reference_x, reference_y, _ = reference_circle
        for idx, image_file in enumerate(image_files):
            image_path = os.path.join(angle_path, image_file)
            image = cv2.imread(image_path)
            
            # Create a mask to focus on the area around the manual reference coordinates
            mask = np.zeros(image.shape[:2], dtype=np.uint8)
            cv2.circle(mask, (reference_x, reference_y), reference_circle_radius, 255, -1)
            masked_image = cv2.bitwise_and(image, image, mask=mask)
            
            # Find circles within the masked area
            circles = find_circles(masked_image)
            if circles is not None:
                for circle in circles[0, :]:
                    x, y, r = circle
                    if hole_diameter_pixels is not None and abs(2 * r - hole_diameter_pixels) < 5:  # Tolerance to match expected hole size
                        # Save alignment reference image
                        alignment_image = image.copy()
                        cv2.circle(alignment_image, (x, y), r, (255, 0, 0), 3)
                        cv2.putText(alignment_image, f"X: {x}, Y: {y}, Diameter: {2*r}", (x - 50, y - 30), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 0), 2)
                        alignment_image_path = os.path.join(angle_path, f'alignment_reference_image_{image_file}')
                        cv2.imwrite(alignment_image_path, alignment_image)
                        positions.append((x, y))
                        break
            else:
                print(f"No circles found in image: {image_file}")

    # Calculate positional accuracy
    if len(positions) > 1:
        print(f"measured {len(positions)} of {len(image_files)} in {angle_folder}")
        distances = []
        capture_numbers = []
        for (x, y), image_file in zip(positions, image_files):
            distance_pixels = np.sqrt((np.int64(x) - np.int64(reference_x)) ** 2 + (np.int64(y) - np.int64(reference_y)) ** 2)
            distance_mm = (distance_pixels / hole_diameter_pixels) * hole_diameter_mm
            distances.append(distance_mm)
            capture_number = int(re.findall(r'\\d+', image_file)[0])
            capture_numbers.append(capture_number)

        # Plot results
        plt.plot(capture_numbers, distances, marker='o')
        plt.xlabel('Capture Number')
        plt.ylabel('Positional Deviation (mm)')
        plt.title(f'Positional Accuracy of Tape Advancement - {angle_folder}')
        plt.grid(True)
        plot_path = os.path.join(angle_path, f'positional_accuracy_plot_{angle_folder}.png')
        plt.savefig(plot_path)
        plt.clf()
    else:
        print(f"Not enough positions found to calculate accuracy in {angle_folder}.")
