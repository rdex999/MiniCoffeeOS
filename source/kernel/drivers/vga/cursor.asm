;
; ---------- [ FUNCTIONS FOR MANIPULATING THE CURSOR ] ----------
;

%ifndef CURSOR_ASM
%define CURSOR_ASM

; Enables the cursor, also initializes it with a scanline (cursor size).
; The highest scanline (size) is 0, and the lowest is 15
; PARAMS
;   - 0) DI   => Cursor start size (bits 0-4)
;   - 1) SI   => Cursor end size (bits 0-4)
; Doesnt return anything
cursorEnable:
  ; Tell VGA we want to set the cursor start scanline
  mov al, 0Ah               ; Prepare register 0Ah - cursor start scanline
  mov dx, VGA_CRTC_CMD      ; Send command on CRTC command port
  out dx, al                ; Tell VGA to prepare register 0Ah at CRTC data port

  ; Set the cursor start scanline, and enable it
  inc dx                    ; DX = 3D5h - CRTC data register
  mov ax, di                ; The cursor start scanline parameter
  and al, 0001_1111b        ; Clear bit 5, which determins if the cursor is enabled or disabled (0 for enabled, 1 for disabled)
  out dx, al                ; Write changes to CRTC data register

  ; Tell VGA we want to set the cursor end scanline
  dec dx                    ; DX = 3D4h - CRTC command register
  mov al, 0Bh               ; Prepare register 0Bh - cursor end scanline
  out dx, al                ; Tell VGA to prepare register 0Bh at CRTC data port

  ; Set the cursor end scanline, and set the cursor skew bits to 1 
  inc dx                    ; DX = 3D5h - CRTC data register
  mov ax, si                ; The cursor end scanline parameter
  or ax, 0110_0000b         ; Make sure bits 5 and 6 are set (cursor skew) so there wont be problems with the cursor disappeating
  out dx, al                ; Write changes to CRTC data register
  
  ret

cursorDisable:
  ; Tell VGA we want to change cursor scanline (which holds the option to disable the cursor)
  mov dx, VGA_CRTC_CMD      ; Send byte on VGA CRTC port
  mov al, 0Ah               ; Prepare register 0Ah - Cursor start scanline register
  out dx, al                ; Tell VGA CRTC to prepare register 0Ah on CRTC data port

  ; Bit 6 of the cursor start scanline registers controles whether the cursor is enabled or disabled (0 - enabled, 1 disabled)
  inc dx                    ; DX = 3D5h - VGA CRTC command port
  mov al, 0010_0000b        ; Turn bit 7 of cursor start scanline register on
  out dx, al                ; Write changes to cursor start scanline register
  ret


; Sets the cursor location from an index in VGA, on the 80x25 screen
; PARAMS
;   - 0) DI   => The VGA index, while each character is 2 bytes.
; Doesnt return anything
setCursorIndex:
  shr di, 1               ; Divide the index by 2, as the VGA expects the index to be in ( row*80 + col ) and not  ( 2*(row*80 + col ) )

  ; Tell VGA we want to set the cursor location (low 8 bits)
  mov dx, VGA_CRTC_CMD    ; Send command to VGA at command port (prepare register)
  mov al, 0Fh             ; Register on index 0Fh - Cursor location low 8 bits register 
  out dx, al              ; Tell VGA to prepare register 0Fh on CRTC data port

  ; Set cursor location low 8 bits
  inc dx                  ; DX = 3D5h - VGA CRTC data port
  mov ax, di              ; Get cursor index parameter in AX
  out dx, al              ; Set cursor location low 8 bits

  ; Tell VGA we want to set the cursor location (high 8 bits)
  dec dx                  ; DX = 3D4h - VGA CRTC command port
  mov al, 0Eh             ; Register on index 0Eh - Cursor location high 8 bits register
  out dx, al              ; Tell VGA to prepare register 0Eh at CRTC data port

  ; Set cursor location high 8 bits
  inc dx                  ; DX = 3D5h - VGA CRTC data port
  mov ax, di              ; Get cursor location parameter in AX
  mov al, ah              ; We want to set the high 8 bits of the cursor location
  out dx, al              ; Set the high 8 bits of the cursor location
  ret

%endif