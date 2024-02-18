; Handles dividing by 0
; Just zeros out the result and the remainder.
ISR_divZero:
  ; Because dibiding by 0 doesnt increase the instruction pointer, gonna have to do so manually
  mov si, sp                ; Get stack pointer in SI
  add word ss:[si], 2       ; Increase the return address to point to the next instruction

  ; Zero out results
  xor ax, ax                ; Zero division result
  xor dx, dx                ; Zero division remainder
  iret