;
; ---------- [ EXTENDED SCAN CODES ] ----------
;

; Acts as an array of key codes, while each index in the array is an extended scan code, which gives you its key code.
; keyArr[extendedScanCode] == keyCode

	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
	db 0, 0, 0, 0, 0, 0, 0, KBD_KEY_RIGHT_ALT, KBD_KEY_PRINT_SCREEN, 0, 
	db KBD_KEY_RIGHT_CTRL, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
	db 0, KBD_KEY_LEFT_WIN, 0, 0, 0, 0, 0, 0, 0, KBD_KEY_RIGHT_WIN, 
	db 0, 0, 0, 0, 0, 0, 0, KBD_KEY_MENUS, 0, 0, 
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
	db 0, 0, 0, 0, KBD_KEY_FORWARD_SLASH_KP, 0, 0, 0, 0, 0, 
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
	db KBD_KEY_ENTER_KP, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
	db 0, 0, 0, 0, 0, KBD_KEY_END, 0, KBD_KEY_LEFT_ARROW, KBD_KEY_HOME, 0, 
	db 0, 0, KBD_KEY_INSERT, KBD_KEY_DELETE, KBD_KEY_DOWN_ARROW, 0, KBD_KEY_RIGHT_ARROW, KBD_KEY_UP_ARROW, 0, 0, 
	db 0, 0, KBD_KEY_PAGE_DOWN, 0, KBD_KEY_PRINT_SCREEN, KBD_KEY_PAGE_UP, 