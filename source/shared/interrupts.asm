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

; Wait for a character from the keyboard, but dont echo it back
; Takes no parameters
; RETURNS
;   - 0) AX   => The character in ascii (low 8 bits - AL)
%define INT_N_WAIT_CHAR_NO_ECHO 6

; Wait for a string input, which ends when the user presses the ENTER key.
; PARAMS
;   - 0) ES:DI  => The buffer to store the data in
;   - 1) SI     => The maximum amount of bytes to read
; RETURNS
;   - 0) AX     => The amount of bytes actualy read
%define INT_N_WAIT_INPUT 7


; Get the current cursor location
; Takes to parameters
; RETURNS
;   - 0) AH   => The row (Y)
;   - 1) AL   => The column (X)
%define INT_N_GET_CURSOR_LOCATION 8


; Set the cursors location
; PARAMS
;   - 0) DI   => The row (Y)
;   - 1) SI   => The column (X)
; Doesnt return anything
%define INT_N_SET_CURSOR_LOCATION 9

; Clear the screen
; Takes no parameters
; Doesnt return anything
%define INT_N_TRM_CLEAR 0Ah

; Get the current color of the terminal
; Doesnt take any parameters
; RETURNS
;   - 0) AX   => The color, lower 8 bits only (AL). 
;        The low 4 bits are the text color, and the high 4 bits are the background color
%define INT_N_TRM_GET_COLOR 0Bh

; Set the terminal color
; PARAMS
;   - 0) DI   => The color, low 4 bits are the text color and the high 4 bits are the background color
; Doesnt return anything
%define INT_N_TRM_SET_COLOR 0Ch

; Open a file from the filesystem in a specific mode.
; FILE ACCESS
;   0 Read ("r")                      - Open the file for reading
;   1 Write ("w")                     - Create file, delete content if exists
;   2 Append ("a")                    - Open for appending to the end of the file, create if doesnt exist
;   3 Read write ("r+")               - Open for both reading and writing, file must exist
;   4 Write read ("w+")               - Create for writing and reading, delete content if the file exists
;   5 Append read ("a+")              - Open file for appending and reading, create file if doesnt exist
; PARAMETERS
;   - 0) ES:DI    => The path to the file, doesnt have to be formatted. Null terminated string.
;   - 1) SI       => Access for the file, low 8 bits only
; RETURNS
;   - 0) In AX, the file handle. A non-zero value on success. (0 on failure)
%define INT_N_FOPEN 0Dh


; Read from an open file at the current read position
; **Parameters are a bit different from the C fread.
; PARAMETERS
;   - 0) ES:DI  => Buffer to read data into
;   - 1) SI     => Number of bytes to read
;   - 2) DX     => File handle
; RETURNS
;   - 0) In AX, the amount of bytes read, can be less then the parameter if an error occurred.
%define INT_N_FREAD 0Eh

; Write to the current position in a file.
; PARAMS
;   - 0) ES:DI  => The buffer of data to be written to the file
;   - 1) SI     => The amount of bytes to write to the file
;   - 2) DX     => A handle to the file
; RETURNS
;   - 0) In AX, the amount of bytes written. Can be less than the requested amount if an error occurs
%define INT_N_FWRITE 0Fh

; Get the system low time, means (lowTime = seconds * 1000 + milliseconds)
; Doesnt take any parameters
; RETURNS
;   - 0) In AX, the low time. (In milliseconds)
%define INT_N_GET_LOW_TIME 10h

; Get the current system time
; Doesnt take any parameters
; RETURNS
;   - 0) In AX, the milliseconds (1000ms = 1 seconds)
;   - 1) In BL, the seconds
;   - 2) In BH, the minutes
;   - 3) In CL, the hour
%define INT_N_GET_SYS_TIME 11h

; Get the current date
; Doesnt take any parameters
; RETURNS
;   - 0) In AL, the week day
;   - 1) In AH, the day in the month
;   - 2) In BL, the month
;   - 3) In BH, the year (add 2000)
%define INT_N_GET_SYS_DATE 12h

; Pause the current process for N milliseconds (1000ms = 1sec)
; PARAMETERS
;   - 0) DI   => The time to sleep, in milliseconds
; Doesnt return anything
%define INT_N_SLEEP 13h


; Terminate the current process. (exit)
; Doesnt take any parameters
; Doesnt return anything
%define INT_N_EXIT 14h

%endif