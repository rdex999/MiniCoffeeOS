;
;   ---------- [ FUNCTIONS THAT RUN ON KERNEL START ] ----------
;

%ifndef INIT_ASM
%define INIT_ASM

%include "source/kernel/macros/macros.asm"
%include "source/kernel/init/ps2_8042.asm"

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
  ; SET_IVT INT_KEYBOARD, cs, ISR_keyboard

  pop es                          ; Restore ES segment
  sti                             ; Enable interrupts

%endmacro

; When the kernel first starts up, need to initialize some things. (Like cpying the BPB from the bootlaoder)
; I made this macro here because it will only be included once.
%macro INIT_KERNEL 0

  ; Copy the BPB and the EBPB from the bootloader 
  COPY_BPB bpbStart
  
  ; 50h << 4 = 500h   // 500h is the end of the IVT and the BIOS data area(as it starts on 0000:0000)
  mov sp, 0FFFFh                    ; Make stack larger
  mov bx, 1000h                       
  mov ss, bx                        ; So make the stack not overwrite the IVT
  mov byte [currentPath], '/'
  
  IVT_INIT

  ; PS2_8042_INIT


%endmacro

%endif