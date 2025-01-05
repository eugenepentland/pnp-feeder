# Linearity Measurement Test for X-Axis Motion

## Overview

This test is designed to **evaluate the linearity of the X-axis motion** in a pick-and-place feeder system. By using an **SG90 servo motor** coupled with a **rack and pinion mechanism**, the system pushes tape along the X-axis. Ensuring linear motion is crucial for the precision and reliability of automated placement tasks.

## Test Purpose

- **Assess Linearity**: Determine how consistently the servo motor translates its rotational steps into linear movement along the X-axis.
- **Identify Deviations**: Detect any inconsistencies or non-linear behaviors in the motion mechanism that could affect placement accuracy.

## Test Methodology

1. **Servo Control**:
   - The SG90 servo motor is commanded to move in incremental steps.
   - Each step corresponds to a specific displacement of the rack and pinion, pushing the tape forward.

2. **Image Capture**:
   - A camera monitors the tape's position along the X-axis.
   - At each servo step, an image is captured to determine the tape's exact position.

3. **Data Collection**:
   - The system processes the captured images to calculate the X-axis position in millimeters.
   - Positions are logged alongside the corresponding servo step indices for analysis.

4. **Stability Check**:
   - Multiple images are taken at each step to ensure reliable and consistent position measurements.
   - Only stable and repeatable measurements are recorded.

## Result Charts Explained

### 1. **X Position vs. Servo Index**

- **Purpose**: Visualizes how the X-axis position changes with each servo step.
- **What to Look For**:
  - **Straight Line**: Indicates perfect linearity; each servo step results in a consistent displacement.
  - **Curvature or Deviations**: Suggests non-linear behavior, which may require calibration or mechanical adjustments.

### 2. **Median X Position with Standard Deviation**

- **Purpose**: Shows the central tendency and variability of the X-axis positions at each servo step.
- **What to Look For**:
  - **Median Line**: Represents the typical X-position for each servo step.
  - **Error Bars (Standard Deviation)**: Indicate the consistency of measurements. Smaller error bars reflect higher precision.

### 3. **Linear Regression Fit**

- **Purpose**: Assesses the relationship between servo steps and X-axis displacement.
- **What to Look For**:
  - **Slope**: Determines how much the X-position changes per servo step. A consistent slope confirms linear motion.
  - **R-squared Value**: Measures how well the data fits the linear model. Values close to 1 indicate strong linearity.

### 4. **Steps Required for Desired Movement**

- **Purpose**: Calculates the number of servo steps needed to achieve a specific linear displacement (e.g., 2 mm).
- **What to Look For**:
  - **Steps per mm**: Helps in setting precise movements for the feeder.
  - **Annotation on Plot**: Provides a quick reference for operational adjustments.

## Interpreting the Results

- **High Linearity**:
  - **Straight Median Line** with **minimal deviation**.
  - **High R-squared Value** (close to 1).
  - **Consistent Steps per mm** indicating reliable motion control.

- **Low Linearity**:
  - **Curved or Irregular Median Line** with **significant deviations**.
  - **Lower R-squared Value**, indicating poor fit to a linear model.
  - **Inconsistent Steps per mm**, which may lead to placement inaccuracies.

## Conclusion

This high-level test effectively measures the **linearity and precision** of the X-axis motion in a servo-driven pick-and-place system. By analyzing the resulting charts, one can determine the reliability of the mechanical setup and make necessary adjustments to ensure accurate and consistent operation.

Regularly performing this test helps maintain the quality and efficiency of automated placement tasks, ensuring that each movement is both precise and predictable.