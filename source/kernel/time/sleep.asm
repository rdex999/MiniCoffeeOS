;
; ---------- [ PAUSE THE CPU FOR n TIME ] ----------
;

; Paused the CPU for N microseconds
; PARAMS
;   - 0) SI:DI    => Time to sleep in microseconds (microseconds = SI * DI)
sleep:

sleep_init:
  mov ax, di                    ; Store old DI

sleep_microsecondInit:
  mov cx, 0290h                 ; Times to loop, this will be exacly one microsecond
sleep_microsecondLoop: 
  loop sleep_microsecondLoop    ; Loop until CX is zero, after that 1 microsecond has passed

  dec di                        ; Decrement microseconds, because one has passed
  jnz sleep_microsecondInit     ; Continue waiting in microseconds as long as DI is not zero

  mov di, ax                    ; Restore DI

  dec si                        ; If DI is zero then decrement SI and restore old DI, then continue looping
  jnz sleep_init                ; as long as SI in not zero. If SI in zero then return

  ret