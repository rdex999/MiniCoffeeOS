;
;   ---------- [ FUNCTIONS THAT RUN ON KERNEL START ] ----------
;

%ifndef INIT_ASM
%define INIT_ASM

%include "source/kernel/macros/macros.asm"

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
  SET_IVT INT_KEYBOARD, cs, ISR_keyboard

  pop es                          ; Restore ES segment
  sti                             ; Enable interrupts

%endmacro

%macro PS2_8042_DISABLE_PORTS 0

  ; Disable ports (devices) on both PS/2s. If there is only one it will ignore the second command
  PS2_SEND_COMMAND PS2_CMD_DISABLE_FIRST_PORT       ; Disable first PS/2 port

  PS2_SEND_COMMAND PS2_CMD_DISABLE_SECOND_PORT      ; Disable second PS/2 port

%endmacro

%macro PS2_8042_SET_CONF_BYTE_DIS_IRQ 0

  ; Read the configuration byte, mask it, save it and write it back.
  PS2_READ_DATA PS2_CMD_READ_CONFIGURATION_BYTE     ; Get the configuration byte in AL

  and al, 00100100b                                 ; Mask the configuration byte. For some reason only this mask works
  mov [bp - 1], al                                  ; Save the mask

  PS2_SEND_COMMAND_DATA PS2_CMD_WRITE_CONFIGURATION_BYTE, al    ; Send the new configuration byte to the PS/2

%endmacro

%macro PS2_8042_SELF_TEST 0

  ; Perform a "self test" to check if the PS/2 isnt dying or some stuff
  PS2_READ_DATA PS2_CMD_SELF_TEST         ; Send the "self test" command and read the result into AL
  cmp al, PS2_SELF_TEST_RESULT_OK         ; If the result is status 55h (ok) then all good
  je %%PS2_8042_SELF_TEST_ok              ; If the result is OK then dont do anything, otherwise panic at the disco

  ; PANIC

%%PS2_8042_SELF_TEST_ok:

%endmacro

%macro PS2_8042_CHECK_TWO_CHANNELS 0

  ; Test the two channels 
  test byte [bp - 1], 00100000b                   ; Check if there is a second PS/2 port
  jnz %%PS2_CHECK_TWO_CHANNELS_end                ; If there is not then quit

  ; Try to enable the second PS/2 port and read the configuration byte, to check if the second PS/2 port is still enabled
  PS2_SEND_COMMAND PS2_CMD_ENABLE_SECOND_PORT     ; Enable the second PS/2 port

  PS2_READ_DATA PS2_CMD_READ_CONFIGURATION_BYTE   ; Read the configuration byte once again into AL

  test al, 00100000b                              ; Check if the second PS/2 port is on
  jz %%PS2_CHECK_TWO_CHANNELS_end                 ; If on then quit, otherwise turn it off and send the command back to the PS/2

  and byte [bp - 1], 11011111b                    ; Turn the second PS/2 port off
  PS2_SEND_COMMAND PS2_CMD_DISABLE_SECOND_PORT    ; Send the new configuration byte to the PS/2

%%PS2_CHECK_TWO_CHANNELS_end:

%endmacro

%macro PS2_8042_INTERFACE_TESTS 0

  ; Perform a test on both PS/2 ports (on the second on only if it exists)
  PS2_READ_DATA PS2_CMD_TEST_FIRST_PORT           ; Send test command to first PS/2 port
  test al, al                                     ; The result will be 0 on success, otherwise some other stuff
  jnz %%PS2_INTERFACE_TESTS_testFailed            ; If its not zero then panic at the disco

  ; *Will get here only if it passed the test
  test byte [bp - 1], 00100000b                   ; Check if there is a second PS/2 port
  jnz %%PS2_INTERFACE_TESTS_end                   ; If not, then quit

  PS2_READ_DATA PS2_CMD_TEST_SECOND_PORT          ; Send the test command to the second PS/2 port
  test al, al                                     ; Check the result (again, 0 on success)
  jz %%PS2_INTERFACE_TESTS_end                    ; If its zero (passed) then quit

  ; Will get here if second PS/2 port has failed
%%PS2_INTERFACE_TESTS_testFailed:
  ; PANIC


%%PS2_INTERFACE_TESTS_end:

%endmacro

%macro PS2_8042_ENABLE_PORTS 0
  ; Enable PS/2 ports and interrupts, (also the second PS/2 port if supported)
  PS2_SEND_COMMAND PS2_CMD_ENABLE_FIRST_PORT      ; Enable the first PS/2 port

  ; Get the configuration byte
  mov bl, [bp - 1]
  or bl, 1b                               ; Enable interrupts for first PS/2 port


  test byte [bp - 1], 00100000b           ; Check if there is a second PS/2 port
  jnz %%PS2_ENABLE_PORTS_end              ; If not then quit

  or bl, 11b                              ; If there is then enable interrupts for it
  PS2_SEND_COMMAND PS2_CMD_ENABLE_SECOND_PORT   ; Enable the second PS/2 port

%%PS2_ENABLE_PORTS_end:
  PS2_SEND_COMMAND_DATA PS2_CMD_WRITE_CONFIGURATION_BYTE, bl    ; Send the new configuration byte to the PS/2 chip


%endmacro

; Initializes the PS/2 8042 micro controller. (the keyboard stuff)
%macro PS2_8042_INIT 0

  ; Initialize the PS/2, as told in the osdev wiki
  push bp
  mov bp, sp
  sub sp, 1
  
  ; By disabling devices, and trying to get data we flush the data buffer
  PS2_8042_DISABLE_PORTS          ; Disable ports (devices)
  in al, PS2_DATA_PORT            ; Try to get data from data port. (flushes it)

  ; Disables IRQs and sets the configuration byte
  PS2_8042_SET_CONF_BYTE_DIS_IRQ

  ; Perform a "self test" on the PS/2
  PS2_8042_SELF_TEST

  ; Check if there is a second PS/2 port
  PS2_8042_CHECK_TWO_CHANNELS

  ; Test both PS/2 chips
  PS2_8042_INTERFACE_TESTS

  ; Enable ports (devices) and IRQs
  PS2_8042_ENABLE_PORTS

  mov sp, bp
  pop bp


%endmacro

; When the kernel first starts up, need to initialize some things. (Like cpying the BPB from the bootlaoder)
; I made this macro here because it will only be included once.
%macro INIT_KERNEL 0

  ; Copy the BPB and the EBPB from the bootloader 
  COPY_BPB bpbStart
  mov sp, 0FFFFh                    ; Make stack larger
  mov byte [currentPath], '/'
  
  IVT_INIT

  PS2_8042_INIT


%endmacro

%endif