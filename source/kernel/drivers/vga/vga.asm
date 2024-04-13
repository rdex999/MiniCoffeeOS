;
; ---------- [ FUNCTIONS FOR VGA ] ----------
;

%ifndef VGA_ASM
%define VGA_ASM

%include "kernel/drivers/vga/cursor.asm"

; Write data to VGA port
; PARAMS
;   - 0) DI   => Port to write
;   - 1) SI   => Register index (lower 8 bits)
;   - 2) DL   => Data
; vgaWriteData:
;   mov dx, di
;   mov ax, si
;   out dx, al

;   inc dx
;   mov al, dl
;   out dx, al
;   ret

%endif