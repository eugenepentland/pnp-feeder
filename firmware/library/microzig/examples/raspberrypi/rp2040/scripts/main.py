
from machine import Pin

# Set up the onboard LED (GPIO25)
led = Pin(25, Pin.OUT)

# Turn on the onboard LED when the Pico is powered on
led.value(1)  # Turn on the LED
