;
; ---------- [ FUNCTIONS FOR MANIPULATING THE CURSOR ] ----------
;

%ifndef CURSOR_ASM
%define CURSOR_ASM

; Enables the cursor, also initializes it with a scanline (cursor size).
; The highest scanline (size) is 0, and the lowest is 15
; PARAMS
;   - 0) DI   => Cursor start size (lower 8 bits)
;   - 1) SI   => Cursor end size (lower 8 bits)
; Doesnt return anything
cursorEnable:
  ; To enable the cursor, we just set its size to a visible size.
  mov al, 0Ah
  mov dx, 3D4h
  out dx, al

  inc dx 
  in al, dx
  and al, 0C0h
  or ax, di

  out dx, al

  dec dx 
  mov al, 0Bh
  out dx, al

  inc dx 
  in al, dx
  and al, 0E0h
  or ax, si

  out dx, al
  ret

cursorDisable:
  mov dx, 3D4h
  mov al, 0Ah 
  out dx, al

  inc dx
  mov al, 0010_0000b
  out dx, al
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