"""What goes wrong with a device being talked to (devlib/mouse.py is the session of a mouse)."""


class DeviceError(Exception):
    """code: denied | busy | gone | timeout | asleep | io | readonly | refused | verify | range | nobackup"""

    def __init__(self, code, message=""):
        super().__init__(message or code)
        self.code = code
