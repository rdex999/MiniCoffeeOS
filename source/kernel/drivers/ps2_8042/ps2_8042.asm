; The PS/2 8042 micro controller chip (keyboard controller) is used to interact with the keyboard,
; and some unrelated stuff that was supported to reduce costs.

; Wait until bit 1 (value = 2) of status register is cleared, means that can send commands.
; Takes no arguments.
ps2_8042_waitInput:
  in al, PS2_STATUS_REGISTER
  test al, 2
  jnz ps2_8042_waitInput
  ret

; Wait until bit 0 (value = 1) of status register is set.
; Basicaly wait until there is data waiting for us in the data port.
; Takes no arguments.
ps2_8042_waitOutput:
  in al, PS2_STATUS_REGISTER
  test al, 1
  jz ps2_8042_waitOutput
  ret