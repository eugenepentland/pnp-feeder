import torch
from PIL import Image, ImageDraw
from transformers import AutoProcessor, AutoModelForZeroShotObjectDetection
import serial
import time
import cv2
import software.tests.servo_position_linearity.messages as messages
import csv
from process import analyze_and_plot_data

result_list = []

# Initialize the model and processor
model_id = "IDEA-Research/grounding-dino-tiny"
device = "cuda" if torch.cuda.is_available() else "cpu"

processor = AutoProcessor.from_pretrained(model_id)
model = AutoModelForZeroShotObjectDetection.from_pretrained(model_id).to(device)

# Clear the CSV file and write the header once at the beginning
def initialize_csv(filename):
    with open(filename, mode="w", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=["angle", "x", "y", "index"])
        writer.writeheader()

# Function to append a row to the CSV file
def append_to_csv(filename, row):
    with open(filename, mode="a", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=row.keys())
        writer.writerow(row)

def crop_by_center(image, center_x, center_y, crop_width, crop_height, output_path=None):
    # Calculate half dimensions
    half_width = crop_width / 2
    half_height = crop_height / 2
    
    # Compute the coordinates of the bounding box
    left = center_x - half_width
    upper = center_y - half_height
    right = center_x + half_width
    lower = center_y + half_height

    # Crop the image
    cropped_image = image.crop((left, upper, right, lower))

    #if output_path is not None:
    cropped_image.save("crop.jpg")
    
    return cropped_image

def draw_dot_on_image(pil_image, x, y, output_path, dot_radius=3, dot_color="red"):
    """Draws a dot (circle) at the given (x, y) coordinates on a PIL Image."""
    draw = ImageDraw.Draw(pil_image)

    # Calculate the bounding box of the dot circle
    left = x - dot_radius
    upper = y - dot_radius
    right = x + dot_radius
    lower = y + dot_radius

    # Draw an ellipse (circle)
    draw.ellipse((left, upper, right, lower), fill=dot_color)
    
    pil_image.save(output_path)
    return pil_image

def get_detection_results(pil_image, text, box_threshold=0.2, text_threshold=0.2,
                          min_width=None, max_width=None, 
                          min_height=None, max_height=None):
    inputs = processor(images=pil_image, text=text, return_tensors="pt").to(device)
    with torch.no_grad():
        outputs = model(**inputs)

    width, height = pil_image.size
    raw_results = processor.post_process_grounded_object_detection(
        outputs,
        inputs.input_ids,
        box_threshold=box_threshold,
        text_threshold=text_threshold,
        target_sizes=[(height, width)]
    )

    if not raw_results:
      return None

    boxes = raw_results[0].get('boxes')
    if boxes is None or (isinstance(boxes, torch.Tensor) and boxes.numel() == 0) or (isinstance(boxes, list) and len(boxes) == 0):
        return None

    # Check and convert if needed
    def to_list(x):
        if torch.is_tensor(x):
            return x.cpu().tolist()
        return x

    boxes = to_list(boxes)
    scores = to_list(raw_results[0].get('scores', []))
    labels = to_list(raw_results[0].get('labels', []))

    filtered_boxes = []
    filtered_scores = []
    filtered_labels = []
    filtered_centers = []

    for box, score, label in zip(boxes, scores, labels):
        x_min, y_min, x_max, y_max = box
        box_w = x_max - x_min
        box_h = y_max - y_min

        # Apply width/height constraints
        if min_width is not None and box_w < min_width:
            continue
        if max_width is not None and box_w > max_width:
            continue
        if min_height is not None and box_h < min_height:
            continue
        if max_height is not None and box_h > max_height:
            continue

        # Compute center coordinates
        center_x = (x_min + x_max) / 2.0
        center_y = (y_min + y_max) / 2.0

        filtered_boxes.append(box)
        filtered_scores.append(score)
        filtered_labels.append(label)
        filtered_centers.append((center_x, center_y))

    if not filtered_centers:
        return None  # No valid detections

    # Find the bounding box with the smallest x-coordinate
    if filtered_centers:
        min_x_center = float('inf')
        min_x_center_index = -1

        for index, center in enumerate(filtered_centers):
            if center[0] < min_x_center:
                min_x_center = center[0]
                min_x_center_index = index
            
        if min_x_center_index != -1:
            return {"x": filtered_centers[min_x_center_index][0], "y": filtered_centers[min_x_center_index][1]}

    return None


def writeMessage(message, ser):
    data = message.serialize()
    ser.write(data)
    _ = ser.read(4)

def capture_and_save(camera, filename, angle, index, ser, min_x_values, max_x_values):
    # Capture the image
    camera = cv2.VideoCapture(0)
    #time.sleep(0.2)
    ret, captured_image = camera.read()
    camera.release() # Release camera when done with this loop

    if not ret:
        print("error reading camera")
        return  # Exit this function if the image is not read

    # Convert OpenCV image to PIL
    captured_image_rgb = cv2.cvtColor(captured_image, cv2.COLOR_BGR2RGB)
    pil_image = Image.fromarray(captured_image_rgb)

    # Crop image
    component_crop = crop_by_center(pil_image, 575, 400, 200, 200)

    detection_text = "rectangle."

    # Get the coordinates of the rectangle
    detection_results = get_detection_results(
        component_crop, 
        detection_text, 
        box_threshold=0.2, 
        text_threshold=0.2,
        min_width=20, 
        max_width=100, 
        min_height=20, 
        max_height=100
    )
    
    x = None
    y = None
    
    save_image = False

    # Handle the result from get_detection_results
    if detection_results:
         x = detection_results["x"]
         y = detection_results["y"]

         # Save the data only if x and y are found
         row = {
              "angle": angle,
              "x": x,
              "y": y,
              "index": index
          }
         append_to_csv(filename, row)  # Save immediately to CSV
         result_list.append(row)  # Optional: Keep in-memory list if needed
         output_img_path = ''

         # Check for new min/max x and save image if needed
         if index not in min_x_values or x < min_x_values[index]:
              min_x_values[index] = x
              save_image = True
              output_img_path = f"img_{index}_{angle}_min.jpg"
              print(f"New min x found for index {index}: {x}")

         if index not in max_x_values or x > max_x_values[index]:
              max_x_values[index] = x
              save_image = True
              output_img_path = f"img_{index}_{angle}_max.jpg"
              print(f"New max x found for index {index}: {x}")

         # Turn off saving an image for now
         save_image = False
         if save_image:
             # Draw the dot on a *copy* of the cropped image, not the function!
             draw_dot_on_image(component_crop.copy(), x, y, output_img_path)

    else:
         print(f"No rectangle detected at angle {angle}")

# Example usage
if __name__ == "__main__":

    initialize_csv("data.csv")
    # Connect to the feeder
    ser = serial.Serial(
        port='/dev/ttyACM0',  # Replace with your serial porQt
        baudrate=115200,
        parity=serial.PARITY_NONE,  # None parity
        stopbits=serial.STOPBITS_ONE,
        bytesize=serial.EIGHTBITS,
        timeout=5
    )
    camera = None

    # Open the connection if it's not already open
    if not ser.is_open:
        ser.open()

    min_x_values = {}
    max_x_values = {}
    
    END_ANGLE = 35

    index = 0
    SPEED = 100
    count = 0

    FINAL_ANGLE = 170
    writeMessage(messages.rotate_servo(0, FINAL_ANGLE, 10), ser)
    #exit()
    while count < 500:

        # Write itermediate positon
        writeMessage(messages.rotate_servo(0, END_ANGLE + 43, SPEED), ser) # 43.6539312 degrees
        capture_and_save(camera, "data.csv", END_ANGLE, 0, ser, min_x_values, max_x_values)

        # Write its position
        writeMessage(messages.rotate_servo(0, END_ANGLE, SPEED), ser)
        capture_and_save(camera, "data.csv", END_ANGLE, 1, ser, min_x_values, max_x_values)
        

        writeMessage(messages.rotate_servo(0, FINAL_ANGLE, SPEED), ser)

        if index == 0:
            index = 1
        else:
            index = 0

        count += 1

        if count % 10 == 0:
            analyze_and_plot_data("data.csv", 0)