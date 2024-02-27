%ifndef INIT_PS2_8042_ASM
%define INIT_PS2_8042_ASM

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

%endif