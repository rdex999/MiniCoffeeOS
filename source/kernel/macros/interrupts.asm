;
; ---------- [ INTERRUPT NUMBERS FOR SERVICES FROM THE KERNEL ] ----------
;

%ifndef INTERRUPTS_ASM
%define INTERRUPTS_ASM

; INT_F   // The interrupt family (int 10h)
; INT_N   // The interrupt number (int 10h / AX = ...)
%define INT_F_KERNEL 20h

; Print a single character at the current cursor position, with echo
; PARAMS
;   - 0) DI   => The color, 0FFh for the current terminal color (lower 8 bits only)
;   - 1) SI   => The character, lower 8 bits only
; Doesnt return anything
%define INT_N_PUTCHAR 0

; Print a single character at a specific location
; PARAMS
;   - 0) DI   => The color, 0FFh for the current terminal color (lower 8 bits only)
;   - 1) SI   => The character, lower 8 bits only
;   - 2) DL   => The column (0 - 79)
;   - 3) DH   => The row (0 - 24)
; Doesnt return anything
%define INT_N_PUTCHAR_LOC 1

; Print a string starting from the current cursor location
; PARAMS
;   - 0) DI     => The color, 0FFh for the current terminal color (lower 8 bits only)
;   - 1) DS:SI  => The string to print, null terminated
; Doesnt return anything
%define INT_N_PUTS 2

; Print a string starting from a specific location
; PARAMS
;   - 0) DI     => The color, 0FFh for the current terminal color (lower 8 bits only)
;   - 1) DS:SI  => The string to print, null terminated
;   - 2) DL     => The column (0 - 79)
;   - 3) DH     => The row (0 - 24)
; Doesnt return anything
%define INT_N_PUTS_LOC 3


%endif