;
;   ---------- [ FUNCTIONS THAT RUN ON KERNEL START ] ----------
;

%ifndef INIT_ASM
%define INIT_ASM

%include "kernel/macros/macros.asm"

%ifdef KBD_DRIVER
  %include "kernel/init/ps2_8042.asm"
%endif

; Copies the BPB and the EBPB from BIOS.
; PARAMS
;   0) lable  => where to copy to
%macro COPY_BPB 1

  pusha
  xor ax, ax
  mov ds, ax
  mov ax, KERNEL_SEGMENT
  mov es, ax

  lea di, %1
  mov si, 7C00h
  mov cx, 62/2        ; BPB + EBPB = 62 // divibe by 2 because increasing pointers by 2
  cld
  repe movsw 
  mov ax, KERNEL_SEGMENT
  mov ds, ax 
  popa

%endmacro

; Sets an interrupt in the IVT. When using this macro ES must be set to 0.
; PARAMS
;   - 0) Interrupt number. (Not the index in the IVT) Must be a constant.
;   - 1) Segment for interrupt handler
;   - 2) Offset for interrupt handler
%macro SET_IVT 3

  mov word es:[%1 * 4], %3
  mov word es:[%1 * 4 + 2], %2

%endmacro

; Initializes the PIC 8259, sets INT offsets in the IVT and stuff
; PARAMS
;   - 0) int8 => Master PIC IRQ offset
;   - 1) int8 => Slave PIC IRQ offset
%macro PIC8259_INIT 2

  ; Save master and slave PICs masks
  in al, PIC_MASTER_DATA                ; Get the master PIC mask
  push ax                               ; Save it
  in al, PIC_SLAVE_DATA                 ; Get the slaves PIC mask
  push ax                               ; And save it

  ; ICW1 (initialization command word) - Start the init process, wait for 3 ICWs
  mov al, ICW1_INIT + ICW1_ICW4
  out PIC_MASTER_CMD, al
  out PIC_SLAVE_CMD, al

  ; ICW2 - The INT offset in the IVT. Send it to both pics
  mov al, %1                      ; First argument is the offset for the master PIC
  out PIC_MASTER_DATA, al         ; Send this offset to the master PIC
  
  mov al, %2                      ; Second argument is the offset for the slave PIC
  out PIC_SLAVE_DATA, al          ; Send it to the slave PIC


  ; ICW3 - Tell both PICs how they are wired
  mov al, 4                       ; IRQ 2, (2*2 = 4)
  out PIC_MASTER_DATA, al         ; Tell the master PIC to accept IRQs from the slave on IRQ 2 (4)

  mov al, 2                       ; Mark for the slave PIC
  out PIC_SLAVE_DATA, al          ; Tell the slave PIC that it is connected to a master PIC


  ; ICW4 - Enable 8086 mode
  mov al, ICW4_8086               ; ICW for 8086 mode
  out PIC_MASTER_DATA, al         ; Enable 8086 mode on master PIC
  out PIC_SLAVE_DATA, al          ; Enable 8086 mode on slave PIC


  ; Restore masks for both PICs
  pop ax                          ; Restore the slaves PICs mask
  out PIC_SLAVE_DATA, al          ; Send it to the slave PIC
  pop ax                          ; Restore the masters PICs mask
  out PIC_MASTER_DATA, al         ; Send it to the master PIC

%endmacro


; Adds interrupt handler to the IVT
%macro IVT_INIT 0

  cli                             ; Disable interrupts, as doing some critical stuff
  push es                         ; Save ES segment
  
  ; Set ES to 0 so SET_IVT will write to the IVT which is located at 0000:0000
  xor bx, bx
  mov es, bx

  ; Initialize both PICs and set offsets
  PIC8259_INIT 8, 8+8

  ; Set ISRs for interrupts 
  SET_IVT INT_DIVIBE_ZERO, cs, ISR_divZero
  SET_IVT INT_PIT_CHANNEL0, cs, ISR_pitChannel_0

%ifdef KBD_DRIVER
  SET_IVT INT_KEYBOARD, cs, ISR_keyboard
%endif

  pop es                          ; Restore ES segment
  sti                             ; Enable interrupts

%endmacro

; Initialize the PIT. Set PIT channel 0 to send N IRQs per second
; PARAMS
;   - 0) The amount of IRQs to send in a second
%macro INIT_PIT 1

  cli                                           ; Disable interrupts while initializing PIT

  ; Set up command for the PIT, 
  ; bits 7-6 - [00] select channel 0 (which sends IRQs)
  ; bits 5-4 - [11] Access mode, (for setting the reload value) set both low part and high part (send first the low part, then high part)
  ; bits 1-3 - [010] Operating mode, Mode 2, For sending IRQs infinitely
  ; bit 0    - [0] BCD/binary mode, BCD is annoying and slow, so im using binary mode
  mov al, 0011_0100b                            ; Set up command for PIT
  out 43h, al                                   ; Send command to PIT

  ; Set up the timing of which channel 0 of the PIT will send IRQs
  ; Formula for getting the right reload value:
  ; reloadVal = cpuClockFrequency / irqPerSec
  mov al, (OSCILLATOR_FREQUENCY / %1) & 0FFh    ; First we send only the low part, as the reload value is 16 bits
  out 40h, al                                  ; Send the lower 8 bits of the reload value

  mov al, (OSCILLATOR_FREQUENCY / %1) >> 8     ; Calculate the high 8 bits of the reload value
  out 40h, al                                  ; Send the high 8 bits of the reload value to the PIT

  sti                                           ; Turn interrupts back on

%endmacro

%macro INIT_DATE_FROM_RTC 0

  mov al, 0Bh                                 ; Register 0Bh - Has some flags that we need to change, like the DM (which controlles BCD mode)
  out CMOS_ACCESS_REG_PORT, al                ; Tell CMOS to prepare access to register 0Bh at its data port
  in al, CMOS_DATA_REG_PORT                   ; Read registers data into AL

  ; flags changed:
  ; bit 0 - DSE {0}   => When 1, daylight saveing is enabled, turned it off (0)
  ; bit 1 - 24/12 {1} => When 1, 24 hours mode is enabled
  ; bit 2 - DM {1}    => When 1, binary mode is used. If 0 then BCD mode is used
  or al, 0000_0110b                           ; Enable some flags
  and al, 1111_1110b                          ; Disable one flag

  mov bl, al                                  ; Store changes in BL

  mov al, 0Bh                                 ; We want to access again this register to update it to the changes we made
  out CMOS_ACCESS_REG_PORT, al                ; Tell CMOS to prepare register 0Bh at its data port
  mov al, bl                                  ; Get the changed value in AL
  out CMOS_DATA_REG_PORT, al                  ; Write the new flags to register 0Bh

%%initDateFromRTC_waitUpdate:
  mov al, 0Ah                                 ; 0Ah - Status register that has the UIP bit, which indicates if there is an update in process
  out CMOS_ACCESS_REG_PORT, al                ; Tell CMOS to prepare register 0Ah at its data port
  in al, CMOS_DATA_REG_PORT                   ; Read registers value into AL
  test al, 1000_0000b                         ; Check if the CMOS is currently doing an update
  jnz %%initDateFromRTC_waitUpdate            ; If it is, continue checking and waiting

  ; Get here if CMOS is not doing an update
  cli                                         ; Disable interrupts while initializing time
  push es                                     ; Save old ES
  mov bx, KERNEL_SEGMENT                      ; Set ES to kernel segment
  mov es, bx                                  ;

  lea di, [sysClock_seconds]                  ; Get a pointer to the seconds
  mov cx, 7                                   ; Copy 7 things (seconds, minutes, hours, weekDay, day, month, year)
  xor al, al                                  ; Start from register 0
  cld                                         ; Clear direction flag so STOSB will increase DI
%%initDateFromRTC_loop:
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
  ja %%initDateFromRTC_loop_afterInc2         ; If by 1 then skip the second increase

  inc al                                      ; If should increase by 2, then increase the register number one more time

%%initDateFromRTC_loop_afterInc2:
  loop %%initDateFromRTC_loop                 ; Continue copying time data until CX is 0

  pop es                                      ; Restore old ES segment
  sti                                         ; Enable interrupts

%endmacro

; When the kernel first starts up, need to initialize some things. (Like cpying the BPB from the bootlaoder)
; I made this macro here because it will only be included once.
%macro INIT_KERNEL 0

  ; Copy the BPB and the EBPB from the bootloader 
  COPY_BPB bpbStart
  
  ; 50h << 4 = 500h   // 500h is the end of the IVT and the BIOS data area(as it starts on 0000:0000)
  mov sp, 7A00h                     ; Make stack larger
  mov bx, 40h                       
  mov ss, bx                        ; So make the stack not overwrite the IVT

  IVT_INIT

  INIT_PIT PIT_CHANNEL0_IRQ_PER_SEC

  %ifdef KBD_DRIVER
    PS2_8042_INIT
  %endif

  call heapInit

  call clear

  mov di, 13
  mov si, 15
  call cursorEnable

  mov di, NORM_SCREEN_START_IDX
  call setCursorIndex
  
  INIT_DATE_FROM_RTC

%endmacro

%endif