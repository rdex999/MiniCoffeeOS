;
; --------- [ TIME RELATED INTERRUPTS ] ---------
;

%ifndef INT_TIME_ASM
%define INT_TIME_ASM

; Get the system low time, means (lowTime = seconds * 1000 + milliseconds)
; Doesnt take any parameters
; RETURNS
;   - 0) In AX, the low time. (In milliseconds)
ISR_getLowTime:
  call getLowTime
  jmp ISR_kernelInt_end

; Get the current system time
; Doesnt take any parameters
; RETURNS
;   - 0) In AX, the milliseconds (1000ms = 1 seconds)
;   - 1) In BL, the seconds
;   - 2) In BH, the minutes
;   - 3) In CL, the hour
ISR_getSysTime:
  push gs
  mov bx, KERNEL_SEGMENT
  mov gs, bx

  mov ax, gs:[sysClock_milliseconds]
  mov bl, gs:[sysClock_seconds]
  mov bh, gs:[sysClock_minutes]
  mov cl, gs:[sysClock_hours]
  xor ch, ch

  pop gs
  jmp ISR_kernelInt_end_restDX


; Get the current date
; Doesnt take any parameters
; RETURNS
;   - 0) In AL, the week day
;   - 1) In AH, the day in the month
;   - 2) In BL, the month
;   - 3) In BH, the year (add 2000)
ISR_getSysDate:
  push gs
  mov bx, KERNEL_SEGMENT
  mov gs, bx

  mov al, gs:[sysClock_weekDay]
  mov ah, gs:[sysClock_day]
  mov bl, gs:[sysClock_month]
  mov bh, gs:[sysClock_year]

  pop gs
  jmp ISR_kernelInt_end_restCX


; Pause the current process for N milliseconds (1000ms = 1sec)
; PARAMETERS
;   - 0) DI   => The time to sleep, in milliseconds
; Doesnt return anything
ISR_sleep:
  push gs                                       ; Set GS to the kernels segment, so we can access the processes array
  mov bx, KERNEL_SEGMENT                        ;
  mov gs, bx                                    ;

  mov al, gs:[currentProcessIdx]                ; Get the current process index
  xor ah, ah                                    ; Zero out high 8 bits
  mov bx, PROCESS_DESC_SIZEOF                   ; We want to multiply by the size of a process descriptor
  mul bx                                        ; Get the process descriptor offset in AX

  lea si, processes                             ; Get a pointer to the processes array
  add si, ax                                    ; Offset it into the current process descriptor

  mov gs:[si + PROCESS_DESC_SLEEP_MS16], di     ; Set the current process sleep time (in MS) to the requested sleep time

  pop gs                                        ; Restore GS
  
  jmp ISR_kernelInt_end                         ; Return from the interrupt

%endif