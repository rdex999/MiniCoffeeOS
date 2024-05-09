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

%endif