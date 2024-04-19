;
; ---------- [ HANDLER FOR PIT INTERRUPTS ] ----------
;

ISR_pitChannel_0:
  push ax                                     ; Save used registers
  push bx                                     ; 
  push es                                     ; Save segment as we are changing it

  mov bx, KERNEL_SEGMENT                      ; Set ES to kernel segemnt
  mov es, bx                                  ; so we can access sysClock variables

  inc word es:[sysClock_milliseconds]         ; The PIT triggers an interrupt every millisecond, so each time increment the sysClock milliseconds
  cmp word es:[sysClock_milliseconds], 1000   ; Check if the milliseconds are more than 1000 (1000ms == 1 seconds)
  jb ISR_pitChannel_0_end                     ; If not, we can return

  ;;;;;;;; DEBUG
  pusha
  call clear
  mov al, es:[sysClock_seconds]
  mov bl, es:[sysClock_minutes]
  xor bh, bh
  xor ah, ah
  PRINTF_M "time %u:%u", bx, ax
  popa

  ; If the milliseconds are higher than 1000 then set them to 0 and increase the sysClock seconds
  mov word es:[sysClock_milliseconds], 0      ; Reset milliseconds
  
  inc byte es:[sysClock_seconds]              ; Increase seconds
  cmp byte es:[sysClock_seconds], 60          ; Check if the seconds are more than 60
  jb ISR_pitChannel_0_end                     ; If not then return

  ; If the seconds are greater or equal to 60 then set the seconds to 0 and increase the minutes
  mov byte es:[sysClock_seconds], 0           ; Set seconds to 0

  inc byte es:[sysClock_minutes]              ; Increase minutes
  cmp byte es:[sysClock_minutes], 60          ; Check if the minutes are more than 60
  jb ISR_pitChannel_0_end                     ; If not then return

  ; If the minutes are greater than 60 then set minutes to 0 and increment the hours
  mov byte es:[sysClock_minutes], 0           ; Set minutes to 0

  inc byte es:[sysClock_hours]                ; Increment hours

ISR_pitChannel_0_end:
  PIC8259_SEND_EOI INT_PIT_CHANNEL0           ; Send EOI to pic so it knows we are finished with the interrupt

  pop es                                      ; Restore segment
  pop bx                                      ; Restore used registers
  pop ax                                      ;
  iret