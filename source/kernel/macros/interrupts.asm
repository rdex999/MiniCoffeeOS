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
;   - 0) DI   => The color, set bit 8 (value: 1_0000_0000b) for the current terminal color
;   - 1) SI   => The character, lower 8 bits only
; Doesnt return anything
%define INT_N_PUTCHAR 0

; Print a single character at a specific location
; PARAMS
;   - 0) DI   => The color, set bit 8 (value: 1_0000_0000b) for the current terminal color
;   - 1) SI   => The character, lower 8 bits only
;   - 2) DL   => The column (0 - 79)
;   - 3) DH   => The row (0 - 24)
; Doesnt return anything
%define INT_N_PUTCHAR_LOC 1

; Print a string starting from the current cursor location
; PARAMS
;   - 0) DI     => The color, set bit 8 (value: 1_0000_0000b) for the current terminal color
;   - 1) DS:SI  => The string to print, null terminated
; Doesnt return anything
%define INT_N_PUTS 2

; Print a string starting from a specific location
; PARAMS
;   - 0) DI     => The color, set bit 8 (value: 1_0000_0000b) for the current terminal color
;   - 1) DS:SI  => The string to print, null terminated
;   - 2) DL     => The column (0 - 79)
;   - 3) DH     => The row (0 - 24)
; Doesnt return anything
%define INT_N_PUTS_LOC 3


; A C-like printf implementation.
; Arguments are pushed to the stack, from right to left
; Pointers are segmented from the DS segment
; Clean the stack yourself!
; PARAMS
;   - 0) A null terminated string
;   - ...) Arguments
; Doesnt return anything
%define INT_N_PRINTF 4

; Wait for a character from the keyboard
; PARAMS
;   - 0) DI   => The color to echo the character with set bit 8 (value: 1_0000_0000b) for the current terminal color
; RETURNS
;   - 0) AX   => The character, in ascii (lower 8 bits - AL)
%define INT_N_WAIT_CHAR 5


%endif