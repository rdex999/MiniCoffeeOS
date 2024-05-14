;
; --------- [ DRAW THE TOP BAR STUFF ] ---------
;

%ifndef DRAW_TOP_BAR_ASM
%define DRAW_TOP_BAR_ASM

%macro DRAW_TOP_BAR_TIME_DATE 0

  ; Set the cursor location to the middle of the first row, minus the size of the time&date / 2
  mov di, 0                                     ; Set row 0
  mov si, (80 / 2) - (21 / 2)                   ; Get column
  mov ax, INT_N_SET_CURSOR_LOCATION             ; Interrupt for setting the cursors location
  int INT_F_KERNEL                              ; Set it

  mov ax, INT_N_GET_SYS_TIME                    ; Interrupt for getting the current system time
  int INT_F_KERNEL                              ; Get the system time (hour, minute, second), in the registers as described in interrupts.asm

  ; Prepare arguments for printf (push from right to left)
  xor dh, dh                                    ; Zero out high 8 bits of the value were gonna push
  mov dl, bl                                    ; Get the seconds in DX
  push dx                                       ; Push them

  mov dl, bh                                    ; Get the minutes in DX
  push dx                                       ; Push them

  mov dl, cl                                    ; Get the hour in DX
  push dx                                       ; Push it

  ; Get the date, year, month, day
  mov ax, INT_N_GET_SYS_DATE                    ; Interrupt for getting the system date
  int INT_F_KERNEL                              ; Get the system date in the registers as described in interrupts.asm

  mov dl, ah                                    ; Get the day in DX
  push dx                                       ; Push it

  mov dl, bl                                    ; Get the month in DX
  push dx                                       ; Push it

  mov dl, bh                                    ; Get the year in DX
  add dx, 2000                                  ; Year starts from 2000
  push dx                                       ; Push it

  push timeAndDateStr                           ; Push the formatting string were gonna use
  mov ax, INT_N_PRINTF                          ; Interrupt for using system printf
  int INT_F_KERNEL                              ; Print it

  add sp, 2 * 7                                 ; Free the stack space that was used for printf's arguments

%endmacro

%endif