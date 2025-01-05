import struct

class empty_msg:
    def __init__(self, hardware_address, message_id = 0):
        # Init all of the fields
        self.message_id = message_id
        self.hardware_address = hardware_address
    
    def serialize(self) -> bytes:
        # Pack integers into a binary format
        # '<' indicates little-endian, 'B' is for unsigned char (1 byte)
        return struct.pack('BB', self.message_id, self.hardware_address, )


    @classmethod
    def deserialize(cls, data: bytes):
        # Unpack binary data back into integers
        message_id, hardware_address,  = struct.unpack('BB', data)
        return cls(hardware_address, message_id)

class error_msg:
    def __init__(self, hardware_address,error_id,  message_id = 1):
        # Init all of the fields
        self.message_id = message_id
        self.hardware_address = hardware_address
        self.error_id = error_id
    
    def serialize(self) -> bytes:
        # Pack integers into a binary format
        # '<' indicates little-endian, 'B' is for unsigned char (1 byte)
        return struct.pack('BBB', self.message_id, self.hardware_address, self.error_id, )


    @classmethod
    def deserialize(cls, data: bytes):
        # Unpack binary data back into integers
        message_id, hardware_address, error_id,  = struct.unpack('BBB', data)
        return cls(hardware_address, error_id, message_id)

class rotate_servo:
    def __init__(self, hardware_address,angle,  message_id = 0):
        # Init all of the fields
        self.message_id = message_id
        self.hardware_address = hardware_address
        self.angle = angle
    
    def serialize(self) -> bytes:
        # Pack integers into a binary format
        # '<' indicates little-endian, 'B' is for unsigned char (1 byte)
        return struct.pack('<BBH', self.message_id, self.hardware_address, self.angle, )


    @classmethod
    def deserialize(cls, data: bytes):
        # Unpack binary data back into integers
        message_id, hardware_address, angle,  = struct.unpack('<BBH', data)
        return cls(hardware_address, angle, message_id)

class set_led_level:
    def __init__(self, hardware_address,level,  message_id = 101):
        # Init all of the fields
        self.message_id = message_id
        self.hardware_address = hardware_address
        self.level = level
    
    def serialize(self) -> bytes:
        # Pack integers into a binary format
        # '<' indicates little-endian, 'B' is for unsigned char (1 byte)
        return struct.pack('BBB', self.message_id, self.hardware_address, self.level, )


    @classmethod
    def deserialize(cls, data: bytes):
        # Unpack binary data back into integers
        message_id, hardware_address, level,  = struct.unpack('BBB', data)
        return cls(hardware_address, level, message_id)

class usb_bootloader:
    def __init__(self, hardware_address, message_id = 125):
        # Init all of the fields
        self.message_id = message_id
        self.hardware_address = hardware_address
    
    def serialize(self) -> bytes:
        # Pack integers into a binary format
        # '<' indicates little-endian, 'B' is for unsigned char (1 byte)
        return struct.pack('BB', self.message_id, self.hardware_address, )


    @classmethod
    def deserialize(cls, data: bytes):
        # Unpack binary data back into integers
        message_id, hardware_address,  = struct.unpack('BB', data)
        return cls(hardware_address, message_id)


def readMessage(buff: bytes):
    messages = {
        0: empty_msg,
        1: error_msg,
        10: rotate_servo,
        101: set_led_level,
        125: usb_bootloader,
    }

    message_id = struct.unpack_from("B", buff, offset=0)[0]

    if not message_id in messages:
        return

    message = messages[message_id]

    return message.deserialize(buff)