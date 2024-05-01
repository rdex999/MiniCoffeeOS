;
; ---------- [ TIME MANIPULATION FUNCTIONS ] ----------
;

%include "kernel/time/sleep.asm"

; Get the low time, meaning the current seconds, with the milliseconds.
; For example the low time for seconds: 14, milliseconds: 724 will be: 14*1000 + 724 = 14724
; Takes to parameters
; RETURNS
;   - 0) In AX, the low time.
getLowTime:
  push gs
  mov bx, KERNEL_SEGMENT
  mov gs, bx 

  mov ax, 1000                              ; Convert the current seconds time into milliseconds
  mov bl, gs:[sysClock_seconds]             ; Get seconds
  xor bh, bh                                ; Zero high 8 bits
  mul bx                                    ; seconds * 1000 = currentMS
  add ax, gs:[sysClock_milliseconds]        ; Add the current milliseconds to the result

.end:
  pop gs
  ret