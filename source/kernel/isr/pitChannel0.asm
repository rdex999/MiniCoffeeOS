;
; ---------- [ HANDLER FOR PIT INTERRUPTS ] ----------
;

%macro SYS_CLOCK_UPDATE_SCREEN_TIME 0

  pusha                                               ; Save all registers, as printf is using all of them
  call getCursorIndex                                 ; Save the current cursor location, so we can change back to it later
  push ax                                             ;

  mov di, GET_CURSOR_INDEX(0, (40 - 20 / 2))          ; Set the cursor location to the middle of the first row on the screen
  call setCursorIndex                                 ;

  ; Clear the time that was printed there before
  push ds                                             ; Save DS segment, bacuase we will change it
  mov bx, es                                          ; Set DS segment to kernel segemnt
  mov ds, bx                                          ; Doing this because the string pointer is using DS
  mov di, COLOR(VGA_TXT_WHITE, VGA_TXT_BLACK)         ; White color, black background
  lea si, [sysClock_20spaces]                         ; Print the 20 spaces string
  mov dx, 20                                          ; Print 20 characters
  call printStrLen                                    ; Perform

  mov di, GET_CURSOR_INDEX(0, (40 - 20 / 2))          ; Set the cursor location to the middle of the first row on the screen
  call setCursorIndex                                 ; because printChar had changed it

  mov al, ds:[sysClock_year]                          ; Get years
  mov bl, ds:[sysClock_month]                         ; Get month
  mov cl, ds:[sysClock_day]                           ; Get day
  mov dl, ds:[sysClock_hours]                         ; Get hours
  and dl, 0111_1111b                                  ; Disable PM bit
  mov si, ds:[sysClock_minutes]                       ; Get minutes
  mov di, ds:[sysClock_seconds]                       ; Get seconds
  xor ah, ah                                          ; Zero out high parts of registers, as each value is 8 bits only
  xor bh, bh                                          ;
  xor ch, ch                                          ;
  xor dh, dh                                          ;
  and si, 0FFh                                        ; Remove the high 8 bits of the minutes
  and di, 0FFh                                        ; Remove the high 8 bits of the seconds
  PRINTF_LM sysClock_onScreenTime, ax, bx, cx, dx, si, di   ; Print all of them
  pop ds                                              ; Restore data segment

  pop di                                              ; Restore original cursor location
  call setCursorIndex                                 ; Set the cursor location to the one that was before
  popa                                                ; Restore all registers

%endmacro

%macro SYS_CLOCK_HANDLE_PIT 0

  inc word es:[sysClock_milliseconds]         ; The PIT triggers an interrupt every millisecond, so each time increment the sysClock milliseconds
  cmp word es:[sysClock_milliseconds], 1000   ; Check if the milliseconds are more than 1000 (1000ms == 1 seconds)
  jb %%isr_sysClockHandlePit_end              ; If not, we can return


  ; If the milliseconds are higher than 1000 then set them to 0 and increase the sysClock seconds
  mov word es:[sysClock_milliseconds], 0      ; Reset milliseconds
  inc byte es:[sysClock_seconds]              ; Increase seconds

  cmp byte es:[sysClock_seconds], 60          ; If the seconds are more than 60, then set RTC interrupt flag, so it will update the time
  jb %%isr_sysClockHandlePit_end              ; If not more than 60, then skip

  ; If a minute have passed, then tell RTC to send interrupts on every time update
  ; And the interrupt service routine (ISR) will update the full time, and it will tell the RTC not to send interrupt
  ; That way RTC sends an interrupt every minute, and we use the PIT for milliseconds
  mov al, 0Bh                                 ; register 0Bh containes the interrupts flag (PIE)
  out CMOS_ACCESS_REG_PORT, al                ; Tell CMOS to prepare access to register 0Bh
  in al, CMOS_DATA_REG_PORT                   ; Read registers value into AL

  or al, 0100_0000b                           ; Enable RTC interrupts
  mov bl, al                                  ; Store changes in BL

  mov al, 0Bh                                 ; Now we want to write out changes back
  out CMOS_ACCESS_REG_PORT, al                ; Tell CMOS to prepare access to register 0Bh
  mov al, bl                                  ; Get updated value in AL
  out CMOS_DATA_REG_PORT, al                  ; Write changes back to register

%%isr_sysClockHandlePit_end:

%endmacro

%macro HANDLE_PROCESSES 0

  ; Prepare for searching a process thats alive
  mov al, es:[currentProcessIdx]                                    ; Get the current running process index
  inc al                                                            ; Increase it by 1 so we wont use the current process
  xor ah, ah                                                        ; Zero out high 8 bits
  mov cx, ax                                                        ; Get a copy of the index in CX
  mov bx, PROCESS_DESC_SIZEOF                                       ; Get the size of a process descriptor
  mul bx                                                            ; Multiply to get the offset into the processes array

  lea si, processes                                                 ; Get a pointer to the processes array
  add si, ax                                                        ; Offset it into the next process
  mov ax, cx                                                        ; Set AX to the next process index
  xor bx, bx                                                        ; BX will be used to determin if we scan the whole array twice (because there might be things before the current index)
%%handleProcesses_searchAlive:
  test byte es:[si + PROCESS_DESC_FLAGS8], PROCESS_DESC_F_ALIVE     ; Check if the current process descriptor is alive
  jnz %%handleProcesses_foundAlive                                  ; If it is, process it and give it controll

  add si, PROCESS_DESC_SIZEOF                                       ; If its not alive, increase the process descriptor pointer to point to the next process
  inc ax                                                            ; Increase index
  cmp ax, PROCESS_DESC_LEN                                          ; Check if the index is above the limit
  jb %%handleProcesses_searchAlive                                  ; As long as its not, continue searching for a living process

  test bx, bx                                                       ; If its above the length, check if BX is set
  jnz %%handleProcesses_end                                         ; If it is, return.

  mov bx, 1                                                         ; If not, set it, so the next time we will return
  lea si, processes                                                 ; Reset the process descriptor pointer
  xor ax, ax                                                        ; Reset the index
  jmp %%handleProcesses_searchAlive                                 ; Continue searching for a living process


%%handleProcesses_foundAlive:

  push ax                                                           ; If we found Save the alive process index
  push si                                                           ; Save the pointer to it in the processes array
  mov al, es:[currentProcessIdx]                                    ; Get the currently running process index
  cmp al, PROCESS_DESC_LEN                                          ; Check if its above the length (it can be)
  jae %%handleProcesses_afterSetPrev                                ; If it is, then dont save the current process registers and stuff

  ; Save the registers of the processes thats currently running, so its possible to get back to it
  ; Calculate the currently running process offset (for the processes array)
  xor ah, ah                                                        ; Zero out high 8 bits of the index
  mov bx, PROCESS_DESC_SIZEOF                                       ; Get the size of a process descriptor
  mul bx                                                            ; Get the offset in AX

  lea si, processes                                                 ; Get a pointer to the processes array
  add si, ax                                                        ; Offset it

  ; Here we save the processes registers
  mov ax, [bp + 6]
  or ax, 1 << 9
  mov es:[si + PROCESS_DESC_REG_FLAGS16], ax

  mov ax, [bp + 4]
  mov es:[si + PROCESS_DESC_REG_CS16], ax
  
  mov ax, [bp + 2]
  mov es:[si + PROCESS_DESC_REG_IP16], ax

  mov ax, [bp]
  mov es:[si + PROCESS_DESC_REG_BP16], ax
  mov es:[si + PROCESS_DESC_REG_SS16], ss
  mov ax, bp
  add ax, 8
  mov es:[si + PROCESS_DESC_REG_SP16], ax

  mov ax, [bp - 2]
  mov es:[si + PROCESS_DESC_REG_AX16], ax

  mov ax, [bp - 4]
  mov es:[si + PROCESS_DESC_REG_BX16], ax

  mov ax, [bp - 6]
  mov es:[si + PROCESS_DESC_REG_CX16], ax

  mov ax, [bp - 8]
  mov es:[si + PROCESS_DESC_REG_DX16], ax

  mov ax, [bp - 10]
  mov es:[si + PROCESS_DESC_REG_SI16], ax

  mov ax, [bp - 12]
  mov es:[si + PROCESS_DESC_REG_DI16], ax

  mov ax, [bp - 14]
  mov es:[si + PROCESS_DESC_REG_DS16], ax

  mov ax, [bp - 16]
  mov es:[si + PROCESS_DESC_REG_ES16], ax

  mov ax, [bp - 18]
  mov es:[si + PROCESS_DESC_REG_FS16], ax

  mov ax, [bp - 20]
  mov es:[si + PROCESS_DESC_REG_GS16], ax

%%handleProcesses_afterSetPrev:
  ; After we saved the currently running process registers, we need to restore the next processes registers
  pop si                                                            ; Restore the alive process descriptor pointer 
  pop ax                                                            ; Restore its index
  
  mov es:[currentProcessIdx], al                                    ; Set the currently running process to the alive one

  ; Reset registers
  mov ax, es:[si + PROCESS_DESC_REG_AX16]
  mov bx, es:[si + PROCESS_DESC_REG_BX16]
  mov cx, es:[si + PROCESS_DESC_REG_CX16]
  mov dx, es:[si + PROCESS_DESC_REG_DX16]
  mov di, es:[si + PROCESS_DESC_REG_DI16]
  mov ds, es:[si + PROCESS_DESC_REG_DS16]
  mov fs, es:[si + PROCESS_DESC_REG_FS16]
  mov gs, es:[si + PROCESS_DESC_REG_GS16]

  mov ss, es:[si + PROCESS_DESC_REG_SS16]
  mov sp, es:[si + PROCESS_DESC_REG_SP16]
  mov bp, es:[si + PROCESS_DESC_REG_BP16]

  ; The IRET instruction will first pop the instruction pointer, then the code segment, and then the flags (16 bit) 
  push word es:[si + PROCESS_DESC_REG_FLAGS16]
  push word es:[si + PROCESS_DESC_REG_CS16]   ; Save next process code segment
  push word es:[si + PROCESS_DESC_REG_IP16]   ; Save next process instruction pointer

  push word es:[si + PROCESS_DESC_REG_ES16]   ; Save next ES (because using it in the next line)
  mov si, es:[si + PROCESS_DESC_REG_SI16]     ; Set next process SI register
  pop es                                      ; Restore ES

  push ax                                     ; Save AX because the EOI signal is using it
  PIC8259_SEND_EOI IRQ_PIT_CHANNEL0           ; Send EOI to pic so it knows we are finished with the interrupt
  pop ax                                      ; Restore AX
  iret

%%handleProcesses_end


%endmacro




ISR_pitChannel_0:
  push bp
  mov bp, sp 
  sub sp, 2 * 10

  mov [bp - 2], ax
  mov [bp - 4], bx
  mov [bp - 6], cx
  mov [bp - 8], dx
  mov [bp - 10], si
  mov [bp - 12], di
  mov [bp - 14], ds
  mov [bp - 16], es
  mov [bp - 18], fs
  mov [bp - 20], gs

  mov bx, KERNEL_SEGMENT                      ; Set ES to kernel segemnt
  mov es, bx                                  ; so we can access sysClock variables

  SYS_CLOCK_HANDLE_PIT

  ; Update the screen clock, checking if the milliseconds are a multiple of 256, so we dont update the screen at 1000 fps
  ; Instead we are updating it on a low fps, on 1000/32 = 31.25 fps (more like 32, but still)
  ; test word es:[sysClock_milliseconds], 32 - 1
  ; jnz ISR_pitChannel_0_afterScreenTimeUpdate    ; If not, then dont update the screen timer
  ; SYS_CLOCK_UPDATE_SCREEN_TIME                  ; 

ISR_pitChannel_0_afterScreenTimeUpdate:

  HANDLE_PROCESSES

ISR_pitChannel_0_end:
  PIC8259_SEND_EOI IRQ_PIT_CHANNEL0           ; Send EOI to pic so it knows we are finished with the interrupt

  mov ax, [bp - 2]
  mov bx, [bp - 4]
  mov cx, [bp - 6]
  mov dx, [bp - 8]
  mov si, [bp - 10]
  mov di, [bp - 12]
  mov ds, [bp - 14]
  mov es, [bp - 16]
  mov fs, [bp - 18]
  mov gs, [bp - 20]

  mov sp, bp
  pop bp
  iret