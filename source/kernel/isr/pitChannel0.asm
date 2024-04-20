;
; ---------- [ HANDLER FOR PIT INTERRUPTS ] ----------
;

%macro SYS_CLOCK_UPDATE_SCREEN_TIME 0

  pusha                                               ; Save all registers, as printf is using all of them
  call getCursorIndex                                 ; Save the current cursor location, so we can change back to it later
  push ax                                             ;

  mov di, GET_CURSOR_INDEX(0, (40 - 20 / 2))          ; Set the cursor location to the middle of the first row on the screen
  call setCursorIndex                                 ;

  ; Clear the time that was printed there before
  mov cx, 20                                          ; Print 23 spaces
%%sysClockUpdateScreen_clearCurrentTime:
  push cx                                             ; Save counter
  mov di, COLOR_CHR(' ', VGA_TXT_BLACK, VGA_TXT_BLACK); Get the space character( ' ' ) and a black color
  call printChar                                      ; Print the character
  pop cx                                              ; Restore color
  loop %%sysClockUpdateScreen_clearCurrentTime        ; Continue printing spaces until cx is 0

  mov di, GET_CURSOR_INDEX(0, (40 - 20 / 2))          ; Set the cursor location to the middle of the first row on the screen
  call setCursorIndex                                 ; because printChar had changed it

  push ds                                             ; Save DS segment, bacuase we will change it
  mov bx, es                                          ; Set DS segment to kernel segemnt
  mov ds, bx                                          ; Doing this because pointers in printf are using the DS segment
  mov al, ds:[sysClock_year]                          ; Get years
  mov bl, ds:[sysClock_month]                         ; Get month
  mov cl, ds:[sysClock_day]                           ; Get day
  mov dl, ds:[sysClock_hours]                         ; Get hours
  and dl, 0111_1111b                                  ; Disable PM bit
  mov si, ds:[sysClock_minutes]                       ; Get minutes
  mov di, ds:[sysClock_seconds]                       ; Get seconds
  xor ah, ah                                          ; Zero out high parts of registers, as each value is 8 bits only
  xor bh, bh                                          ;
  xor ch, ch                                          ;
  xor dh, dh                                          ;
  and si, 0FFh                                        ; Remove the high 8 bits of the minutes
  and di, 0FFh                                        ; Remove the high 8 bits of the seconds
  PRINTF_LM sysClock_onScreenTime, ax, bx, cx, dx, si, di   ; Print all of them
  pop ds                                              ; Restore data segment

  pop di                                              ; Restore original cursor location
  call setCursorIndex                                 ; Set the cursor location to the one that was before
  popa                                                ; Restore all registers

%endmacro

%macro SYS_CLOCK_HANDLE_PIT 0

  inc word es:[sysClock_milliseconds]         ; The PIT triggers an interrupt every millisecond, so each time increment the sysClock milliseconds
  cmp word es:[sysClock_milliseconds], 1000   ; Check if the milliseconds are more than 1000 (1000ms == 1 seconds)
  jb %%isr_sysClockHandlePit_end              ; If not, we can return


  ; If the milliseconds are higher than 1000 then set them to 0 and increase the sysClock seconds
  mov word es:[sysClock_milliseconds], 0      ; Reset milliseconds
  
%%isr_sysClockHandlePit_end:

%endmacro



ISR_pitChannel_0:
  push ax                                     ; Save used registers
  push bx                                     ; 
  push dx
  push es                                     ; Save segment as we are changing it

  mov bx, KERNEL_SEGMENT                      ; Set ES to kernel segemnt
  mov es, bx                                  ; so we can access sysClock variables

  SYS_CLOCK_HANDLE_PIT

  ; Update the screen clock, checking if the milliseconds are a multiple of 256, so we dont update the screen at 1000 fps
  ; Instead we are updating it on a low fps, on 1000/32 = 31.25 fps (more like 32, but still)
  test word es:[sysClock_milliseconds], 32 - 1
  jnz ISR_pitChannel_0_afterScreenTimeUpdate    ; If not, then dont update the screen timer
  SYS_CLOCK_UPDATE_SCREEN_TIME                  ; 

ISR_pitChannel_0_afterScreenTimeUpdate:
ISR_pitChannel_0_end:
  PIC8259_SEND_EOI INT_PIT_CHANNEL0           ; Send EOI to pic so it knows we are finished with the interrupt

  pop es                                      ; Restore segment
  pop dx
  pop bx                                      ; Restore used registers
  pop ax                                      ;
  iret