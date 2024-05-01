;
; ---------- [ PAUSE THE CPU FOR n TIME ] ----------
;

; Paused the CPU for N microseconds
; PARAMS
;   - 0) DI   => Time to sleep, in milliseconds (1000 milliseconds = 1 second)
sleep:
  push gs                                   ; Save GS, because were changing it
  mov bx, KERNEL_SEGMENT                    ; Set GS to the kernels segment so we can access sysClock
  mov gs, bx                                ;

  mov ax, 1000                              ; Convert the current seconds time into milliseconds
  mov bl, gs:[sysClock_seconds]             ; Get seconds
  xor bh, bh                                ; Zero high 8 bits
  mul bx                                    ; seconds * 1000 = currentMS
  add ax, gs:[sysClock_milliseconds]        ; Add the current milliseconds to the result

  mov si, ax                                ; Save the starting time in SI

  sti                                       ; Enable interrupts, so the HLT instruction doesnt get us in an infinite loop
.waitLoop:
  hlt                                       ; Halt until there is an interrupt (which happens every milliseconds from the PIT)

  ; Here we calculate the current time in MS, and check if the difference 
  ; between the current time and the starting is greater then the requested time to wait.
  ; If its not greater then the requested time, continue waiting
  ; something like:
  ; uint16_t startTime = sysClock_seconds * 1000 + sysClock_milliseconds;
  ; while((sysClock_seconds * 1000 + sysClock_milliseconds) < startTime) {}
  ; return;
  mov ax, 1000                              ; Get the size of a second, in milliseconds
  mov bl, gs:[sysClock_seconds]             ; Get current seconds
  xor bh, bh                                ; Zero high 8 bits
  mul bx                                    ; Get current seconds in MS
  add ax, gs:[sysClock_milliseconds]        ; Add to it the current MS

  sub ax, si                                ; Calculate the difference between the current time and the starting time
  cmp ax, di                                ; Check if the difference is greater then the requested time to wait
  jb .waitLoop                              ; If not, continue waiting

.end:
  pop gs                                    ; Restore GS
  ret