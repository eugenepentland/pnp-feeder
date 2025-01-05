import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from scipy.stats import linregress

def analyze_and_plot_data(
    output_file, 
    min_attempt=350, 
    lower_index=250, 
    upper_index=750, 
    movement_distance_mm=2
):
    """
    Analyzes and plots X position data from a CSV file, filtering by a minimum attempt number and index bounds.
    Additionally, calculates how many angle steps correspond to a specified movement distance in X.
    
    Args:
        output_file (str): The path to the CSV data file.
        min_attempt (int): The minimum attempt number to include in the analysis.
        lower_index (int): The lower bound for the 'index' (servo angle steps).
        upper_index (int): The upper bound for the 'index' (servo angle steps).
        movement_distance_mm (float): The desired movement distance in millimeters.
    """

    # Constants
    CIRCLE_DIAMETER_PIXELS = 72  # Diameter in pixels
    CIRCLE_DIAMETER_MM = 1.4      # Actual diameter in millimeters
    PIXEL_TO_MM_SCALE = CIRCLE_DIAMETER_MM / CIRCLE_DIAMETER_PIXELS  # ≈0.01944 mm per pixel

    # Read the CSV file
    df = pd.read_csv(output_file)

    # Ensure the CSV has the expected columns
    expected_columns = {'x_position_mm', 'index'}
    if not expected_columns.issubset(df.columns):
        raise ValueError(f"CSV file must contain columns: {expected_columns}")

    # Convert 'x_position_mm' from pixels to mm if necessary
    # Assuming 'x_position_mm' is already in mm, otherwise adjust accordingly
    if 'x_mm' not in df.columns:
        df['x_mm'] = df['x_position_mm']  # If already in mm

    # Create an 'attempt' column based on the order within each 'index' group
    df['attempt'] = df.groupby('index').cumcount() + 1

    # Filter data to include only attempts above min_attempt and index within bounds
    df_filtered = df[
        (df['attempt'] > min_attempt) &
        (df['index'] >= lower_index) &
        (df['index'] <= upper_index)
    ]

    if df_filtered.empty:
        print(f"No data available after filtering attempts > {min_attempt} and index between {lower_index} and {upper_index}.")
        return

    # Group by index and calculate statistics for x in mm, using the filtered data
    result = df_filtered.groupby("index", as_index=True).agg({
        "x_mm": ["mean", "std", "min", "max"],
        "attempt": "count"
    })

    # Flatten multi-level column names
    result.columns = ["average_x_mm", "std_x_mm", "min_x_mm", "max_x_mm", "total_attempts"]

    # Print the result to verify
    print("Statistical Summary:")
    print(result)

    # --- Linear Regression to Determine Steps for Specified Movement ---
    # Aggregate the average x_mm per index
    regression_data = result.reset_index()

    # Perform linear regression: x_mm vs index
    slope, intercept, r_value, p_value, std_err = linregress(regression_data['index'], regression_data['average_x_mm'])

    print("\nLinear Regression Results:")
    print(f"Slope (dx/dindex): {slope:.6f} mm per step")
    print(f"Intercept: {intercept:.6f} mm")
    print(f"R-squared: {r_value**2:.6f}")

    if slope == 0:
        print("Slope is zero, cannot compute steps for movement.")
        steps_per_mm = None
        steps_for_distance = None
    else:
        # Calculate steps required for the specified movement distance
        steps_per_mm = 1 / slope  # steps per mm
        steps_for_distance = movement_distance_mm * steps_per_mm

        print(f"\nCalculated Steps for {movement_distance_mm} mm Movement:")
        print(f"Steps per mm: {steps_per_mm:.2f} steps/mm")
        print(f"Steps for {movement_distance_mm} mm: {steps_for_distance:.2f} steps")

    # --- Plotting ---
    plt.figure(figsize=(12, 8))

    # Plot average x_mm vs index with error bars (std dev)
    plt.errorbar(
        regression_data['index'],
        regression_data['average_x_mm'],
        yerr=regression_data['std_x_mm'],
        fmt='o',
        ecolor='lightgray',
        elinewidth=3,
        capsize=0,
        label='Average X Position with Std Dev',
        color='blue'
    )

    # Plot the linear regression line
    x_vals = np.array([regression_data['index'].min(), regression_data['index'].max()])
    y_vals = intercept + slope * x_vals
    plt.plot(x_vals, y_vals, '--', color='red', label='Linear Regression Fit')

    # Annotate the plot with steps for the specified movement distance
    if slope != 0:
        plt.text(
            0.05, 0.95,
            f'Steps for {movement_distance_mm} mm: {steps_for_distance:.2f} steps',
            transform=plt.gca().transAxes,
            fontsize=12,
            verticalalignment='top',
            bbox=dict(boxstyle='round', facecolor='white', alpha=0.5)
        )

    plt.xlabel('Index (Angle Steps)')
    plt.ylabel('X Position (mm)')
    plt.title(f'X Position vs Angle Steps (Attempts > {min_attempt}, Index {lower_index}-{upper_index})')
    plt.legend()
    plt.grid(True)

    # Save the plot with descriptive filename
    plot_filename = f'x_position_analysis_attempt_{min_attempt}_index_{lower_index}_{upper_index}.png'
    plt.savefig(plot_filename)
    print(f"\nSaved plot to {plot_filename}")
    # plt.show()

# Example usage:
if __name__ == "__main__":
    data_file = "data.csv"  # Update this with your data file path
    analyze_and_plot_data(
        output_file=data_file,
        min_attempt=0,
        lower_index=250,
        upper_index=750,
        movement_distance_mm=2
    )
    # You can also specify different bounds and movement distances:
    # analyze_and_plot_data(data_file, min_attempt=350, lower_index=200, upper_index=800, movement_distance_mm=3)
