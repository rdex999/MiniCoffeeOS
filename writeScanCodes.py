#!/bin/python3
from operator import attrgetter

keyCount = 0

class key:
    def __init__(self, scanCode: int, name: str, ascii: int = 0, extendedScanCodes: list = [0]) -> None:
        self.scanCode = scanCode
        self.name = name
        self.ascii = ascii
        self.extendedScanCodes = extendedScanCodes
        global keyCount
        self.keyCode = keyCount + 1
        keyCount += 1



keyMapStr = """;
; ---------- [ SCAN CODES ] ----------
;

; Acts as an array of key codes, while each index in the array is a scan code, which gives you its key code.
; keyArr[scanCode] == keyCode
"""

keyMapExtendedStr = """;
; ---------- [ EXTENDED SCAN CODES ] ----------
;

; Acts as an array of key codes, while each index in the array is an extended scan code, which gives you its key code.
; keyArr[extendedScanCode] == keyCode
"""

keyDefStr = """;
; ---------- [ %DEFINE FOR ALL KEYBOARD KEY CODES ] ----------
;

"""

keyAsciiStr = """;
; ---------- [ TRANSLATION FROM KEYCODES TO ASCII ] ----------
;

; Acs as an array of ascii characters, when each index in the array in a keycode, which gives you its ascii code.
; keyAsciiArr[keyCode] == asciiCode
"""

keys = [

    # ========== [ FIRST ROW ] ==========
    key(scanCode=0x76, name="ESC", ascii=0x1B),
    key(scanCode=0x05, name="F1"),
    key(scanCode=0x06, name="F2"),
    key(scanCode=0x04, name="F3"),
    key(scanCode=0x0C, name="F4"),
    key(scanCode=0x03, name="F5"),
    key(scanCode=0x0B, name="F6"),
    key(scanCode=0x83, name="F7"),
    key(scanCode=0x0A, name="F8"),
    key(scanCode=0x01, name="F9"),
    key(scanCode=0x09, name="F10"),
    key(scanCode=0x78, name="F11"),
    key(scanCode=0x07, name="F12"),
    key(scanCode=0, name="PRINT_SCREEN", ascii=0, extendedScanCodes=[0x12, 0x7C]),
    key(scanCode=0x7E, name="SCROLL_LOCK"),
    key(scanCode=0, name="PAUSE_BREAK", ascii=0, extendedScanCodes=[0,]),
    
    # ========== [ SECOND ROW ] ==========
    key(scanCode=0x0E, name="GRAVE", ascii=0x60),
    
    key(scanCode=0x16, name="1", ascii=0x31),
    key(scanCode=0x1E, name="2", ascii=0x32),
    key(scanCode=0x26, name="3", ascii=0x33),
    key(scanCode=0x25, name="4", ascii=0x34),
    key(scanCode=0x2E, name="5", ascii=0x35),
    key(scanCode=0x36, name="6", ascii=0x36),
    key(scanCode=0x3D, name="7", ascii=0x37),
    key(scanCode=0x3E, name="8", ascii=0x38),
    key(scanCode=0x46, name="9", ascii=0x39),
    key(scanCode=0x45, name="0", ascii=0x30),
    
    key(scanCode=0x4E, name="MINUS", ascii=0x2D),
    key(scanCode=0x55, name="EQUAL", ascii=0x3D),
    key(scanCode=0x66, name="BACKSPACE", ascii=0x08),
    
    # ========== [ THIRD ROW ] ==========
    key(scanCode=0x0D, name="TAB", ascii=0x09),
    key(scanCode=0x15, name="Q", ascii=0x71),
    key(scanCode=0x1D, name="W", ascii=0x77),
    key(scanCode=0x24, name="E", ascii=0x65),
    key(scanCode=0x2D, name="R", ascii=0x72),
    key(scanCode=0x2C, name="T", ascii=0x74),
    key(scanCode=0x35, name="Y", ascii=0x79),
    key(scanCode=0x3C, name="U", ascii=0x75),
    key(scanCode=0x43, name="I", ascii=0x69),
    key(scanCode=0x44, name="O", ascii=0x6F),
    key(scanCode=0x4D, name="P", ascii=0x70),
    key(scanCode=0x54, name="OPEN_BRACKET", ascii=0x5B),
    key(scanCode=0x5B, name="CLOSED_BRACKET", ascii=0x5D),
    key(scanCode=0x5D, name="BACK_SLASH", ascii=0x5C),

    # ========== [ FOURTH ROW ] ==========
    key(scanCode=0x58, name="CAPSLOCK"),
    key(scanCode=0x1C, name="A", ascii=0x61),
    key(scanCode=0x1B, name="S", ascii=0x73),
    key(scanCode=0x23, name="D", ascii=0x64),
    key(scanCode=0x2B, name="F", ascii=0x66),
    key(scanCode=0x34, name="G", ascii=0x67),
    key(scanCode=0x33, name="H", ascii=0x68),
    key(scanCode=0x3B, name="J", ascii=0x6A),
    key(scanCode=0x42, name="K", ascii=0x6B),
    key(scanCode=0x4B, name="L", ascii=0x6C),
    key(scanCode=0x4C, name="SEMICOLON", ascii=0x3B),
    key(scanCode=0x52, name="SINGLE_QUOTE", ascii=0x27),
    key(scanCode=0x5A, name="ENTER", ascii=0x0D),

    # ========== [ FIFTH ROW ] ==========
    key(scanCode=0x12, name="LEFT_SHIFT"),
    key(scanCode=0x1A, name="Z", ascii=0x7A),
    key(scanCode=0x22, name="X", ascii=0x78),
    key(scanCode=0x21, name="C", ascii=0x63),
    key(scanCode=0x2A, name="V", ascii=0x76),
    key(scanCode=0x32, name="B", ascii=0x62),
    key(scanCode=0x31, name="N", ascii=0x6E),
    key(scanCode=0x3A, name="M", ascii=0x6D),
    key(scanCode=0x41, name="COMMA", ascii=0x2C),
    key(scanCode=0x49, name="DOT", ascii=0x2E),
    key(scanCode=0x4A, name="FORWARD_SLASH", ascii=0x2F),
    key(scanCode=0x59, name="RIGHT_SHIFT"),

    # ========== [ SIXTH ROW ] ==========
    key(scanCode=0x14, name="LEFT_CTRL"),
    key(scanCode=0, name="LEFT_WIN", ascii=0, extendedScanCodes=[0x1F,]),
    key(scanCode=0x11, name="LEFT_ALT"),
    key(scanCode=0x29, name="SPACE", ascii=0x20),
    key(scanCode=0, name="RIGHT_ALT", ascii=0, extendedScanCodes=[0x11,]),
    key(scanCode=0, name="RIGHT_WIN", ascii=0, extendedScanCodes=[0x27,]),
    key(scanCode=0, name="MENUS", ascii=0, extendedScanCodes=[0x2F,]),
    key(scanCode=0, name="RIGHT_CTRL", ascii=0, extendedScanCodes=[0x14,]),
    key(scanCode=0, name="INSERT", ascii=0, extendedScanCodes=[0x70,]),
    key(scanCode=0, name="HOME", ascii=0, extendedScanCodes=[0x6C,]),
    key(scanCode=0, name="PAGE_UP", ascii=0, extendedScanCodes=[0x7D,]),
    key(scanCode=0, name="DELETE", ascii=0, extendedScanCodes=[0x71,]),
    key(scanCode=0, name="END", ascii=0, extendedScanCodes=[0x69,]),
    key(scanCode=0, name="PAGE_DOWN", ascii=0, extendedScanCodes=[0x7A,]),
    key(scanCode=0, name="UP_ARROW", ascii=0, extendedScanCodes=[0x75,]),
    key(scanCode=0, name="LEFT_ARROW", ascii=0, extendedScanCodes=[0x6B,]),
    key(scanCode=0, name="DOWN_ARROW", ascii=0, extendedScanCodes=[0x72,]),
    key(scanCode=0, name="RIGHT_ARROW", ascii=0, extendedScanCodes=[0x74]),


    # ========== [ KEYPAD ] ==========
    key(scanCode=0x77, name="NUMLOCK"),
    key(scanCode=0, name="FORWARD_SLASH_KP", ascii=0x2F, extendedScanCodes=[0x4A,]),
    key(scanCode=0x7C, name="ASTERISK_KP", ascii=0x2A),
    key(scanCode=0x7B, name="MINUS_KP", ascii=0x2D),
    key(scanCode=0x6C, name="7_KP", ascii=0x37),
    key(scanCode=0x75, name="8_KP", ascii=0x38),
    key(scanCode=0x7D, name="9_KP", ascii=0x39),
    key(scanCode=0x79, name="PLUS_KP", ascii=0x2B),
    key(scanCode=0x6B, name="4_KP", ascii=0x34),
    key(scanCode=0x73, name="5_KP", ascii=0x35),
    key(scanCode=0x74, name="6_KP", ascii=0x36),
    key(scanCode=0x69, name="1_KP", ascii=0x31),
    key(scanCode=0x72, name="2_KP", ascii=0x32),
    key(scanCode=0x7A, name="3_KP", ascii=0x33),
    key(scanCode=0x70, name="0_KP", ascii=0x30),
    key(scanCode=0x71, name="DOT_KP", ascii=0x2E),
    key(scanCode=0, name="ENTER_KP", ascii=0x0D, extendedScanCodes=[0x5A,])
]

def findKeycode(name: str) -> int:
    for akey in keys:
        if akey.name == name:
            return akey.asciie

for i in range(len(keys)):
    cnt = 0 
    for j in range(len(keys)):
        if keys[i].scanCode != 0 and keys[i].scanCode == keys[j].scanCode:
            if cnt >= 1:
                print(f"ERROR: found duplicate on index {i} with scan code {keys[i].scanCode} and name {keys[i].name}") 
                exit(1)
            cnt += 1



keys.sort(key=attrgetter("scanCode"))

# for aKey in keys:
#     print("key: " + str(aKey.name) + "\t\tscan code: " + str(aKey.scanCode) + "\t\tkey code: " + str(aKey.keyCode))
for akey in keys:
    keyDefStr += f"%define KBD_KEY_{akey.name} {akey.keyCode}\n"

keyDefFile = open("source/kernel/macros/kbdKeyCodes.asm", "+w")
keyDefFile.write(keyDefStr)
keyDefFile.close()




# Create the scan code array, for normal keys
keyMap = [0] * (max([akey.scanCode for akey in keys]) + 1)
for akey in keys:
    if akey.scanCode != 0:
        keyMap[akey.scanCode] = f"KBD_KEY_{akey.name}"

perLine = 0
for item in keyMap:
    if perLine % 10 == 0:
        keyMapStr += "\n\tdb "
    
    keyMapStr += f"{item}, "
    perLine += 1

keyMapFile = open("source/kernel/drivers/ps2_8042/kbdScanCodes.asm", "+w")
keyMapFile.write(keyMapStr)
keyMapFile.close()


# Create the scan code array for extended key codes
keyExtendedMap = [0] * (max([max(akey.extendedScanCodes) for akey in keys]) + 1)
for akey in keys:
    if akey.extendedScanCodes[0] != 0:
        for extScanCode in akey.extendedScanCodes:
            keyExtendedMap[extScanCode] = f"KBD_KEY_{akey.name}"
        # keyExtendedMap[akey.extendedScanCodes[0]] = f"KBD_KEY_{akey.name}"

perLine = 0
for item in keyExtendedMap:
    if perLine % 10 == 0:
        keyMapExtendedStr += "\n\tdb "
    
    keyMapExtendedStr += f"{item}, "
    perLine += 1

keyMapFile = open("source/kernel/drivers/ps2_8042/kbdExtendedScanCodes.asm", "+w")
keyMapFile.write (keyMapExtendedStr)
keyMapFile.close()




keys.sort(key=attrgetter("keyCode"))

perLine = 0
for akey in keys:
    if perLine % 10 == 0:
        keyAsciiStr += "\n\tdb "

    char = chr(akey.ascii)
    if char.isalpha():
        keyAsciiStr += f"'{char}', "
    else:
        keyAsciiStr += f"{akey.ascii}, "

    perLine += 1


keyAsciiFile = open("source/kernel/drivers/ps2_8042/kbdAsciiCodes.asm", "+w")
keyAsciiFile.write(keyAsciiStr)
keyAsciiFile.close()

