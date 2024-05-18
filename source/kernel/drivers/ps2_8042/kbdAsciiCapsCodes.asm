;
; ---------- [ TRANSLATION FROM KEYCODES TO CAPITAL ASCII ] ----------
;

; Acts as an array of capital ascii characters when each index in the array is a keycode, which gives you its capital ascii code.
; keyCapitalAsciiArr[keyCode] == capitalAsciiCode
; keyCapitalAsciiArr[KBD_KEY_1] == '!'

	db 27, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
	db 0, 0, 0, 0, 0, 0, 126, 33, 64, 35, 
	db 36, 37, 94, 38, 42, 40, 41, 95, 43, 8, 
	db 9, 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 
	db 'P', 123, 125, 124, 0, 'A', 'S', 'D', 'F', 'G', 
	db 'H', 'J', 'K', 'L', 58, 34, 13, 0, 'Z', 'X', 
	db 'C', 'V', 'B', 'N', 'M', 60, 62, 63, 0, 0, 
	db 0, 0, 32, 0, 0, 0, 0, 0, 0, 0, 
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
	db 0, 0, 0, 0, 