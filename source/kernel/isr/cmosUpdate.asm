;
; ---------- [ INTERRUPT HANDLER FOR CMOS UPDATES ] ----------
;

%ifndef CMOS_UPDATE_ASM
%define CMOS_UPDATE_ASM

ISR_cmosUpdate:
  push ax                                     ; Save used registers
  push bx                                     ;
  push cx                                     ;
  push di                                     ;
  push es                                     ; Save old ES

  mov bx, KERNEL_SEGMENT                      ; Set ES to kernel segment
  mov es, bx                                  ;

  lea di, [sysClock_seconds]                  ; Get a pointer to the seconds
  mov cx, 7                                   ; Copy 7 things (seconds, minutes, hours, weekDay, day, month, year)
  xor al, al                                  ; Start from register 0
  cld                                         ; Clear direction flag so STOSB will increase DI
.copyDataLoop:
  or al, NMI_STATUS_BIT_CMOS                  ; Disable NMI
  out CMOS_ACCESS_REG_PORT, al                ; Tell CMOS to prepare register number <AL> in its data port
  and al, 0111_1111b                          ; Clear NMI bit, so the INC instruction (later on) will not mess up the register number
  push ax                                     ; Save current register number
  in al, CMOS_DATA_REG_PORT                   ; Read CMOS register value into AL
  stosb                                       ; Store the value in the matching variable for it (sysClock_seconds, minutes, ...)
  pop ax                                      ; Restore CMOS register counter
  inc al                                      ; Increase register
  
  ; Register 0 - 4 (seconds[0], minutes[2], hours[4]) are increasing by 2,
  ; while registers 6 - 9 (weekDay[6], day[7], year[8]) are increasing by 1
  cmp al, 6 - 1                               ; Check if should increase by 2 or 1
  ja .copyDataLoop_afterSecondsInc            ; If by 1 then skip the second increase

  inc al                                      ; If should increase by 2, then increase the register number one more time

.copyDataLoop_afterSecondsInc:
  loop .copyDataLoop                          ; Continue copying time data until CX is 0

.end:

  ; Now we want to disable RTC interrupts, and the PIT will enable them once every minute.
  mov al, 0Bh | NMI_STATUS_BIT_CMOS           ; Interrupts flag (PIE) is in register 0Bh of CMOS
  out CMOS_ACCESS_REG_PORT, al                ; Tell CMOS to prepare register 0Bh in its data port
  in al, CMOS_DATA_REG_PORT                   ; Read registers value

  and al, 1011_1111b                          ; Disable interrupts flag (PIE)
  mov bl, al                                  ; Store changes in BL

  mov al, 0Bh | NMI_STATUS_BIT_CMOS           ; Now we want to write out changes back to this register
  out CMOS_ACCESS_REG_PORT, al                ; Tell CMOS to prepare register 0Bh in data port
  mov al, bl                                  ; Get the updated flags in AL
  out CMOS_DATA_REG_PORT, al                  ; Write changes back to register

  ; After an RTC interrupt, register 0Ch will contain a bitmask of which interrupt just happened.
  ; If we do not read this value the RTC wont send more interrupts.
  mov al, 0Ch | NMI_STATUS_BIT_CMOS           ; Need to read this register
  out CMOS_ACCESS_REG_PORT, al                ; Tell CMOS we want access to register 0Ch
  in al, CMOS_DATA_REG_PORT                   ; Read registers value. We dont care what it is, just read it

  PIC8259_SEND_EOI INT_CMOS_UPDATE            ; Tell PIC we are done with this interrupt
  pop es                                      ; Restore segments
  pop di                                      ; Restore used registers
  pop cx                                      ;
  pop bx                                      ;
  pop ax                                      ;
  iret
%endif