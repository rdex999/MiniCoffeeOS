;
; ---------- [ TRANSLATION FROM KEYCODES TO ASCII ] ----------
;

; Acs as an array of ascii characters, when each index in the array in a keycode, which gives you its ascii code.
; keyAsciiArr[keyCode] == asciiCode

	db 27, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
	db 0, 0, 0, 96, 49, 50, 51, 52, 53, 54, 
	db 55, 56, 57, 48, 45, 61, 8, 9, 113, 119, 
	db 101, 114, 116, 121, 118, 105, 111, 112, 91, 93, 
	db 92, 0, 97, 115, 100, 102, 103, 104, 106, 107, 
	db 108, 59, 39, 13, 0, 122, 120, 99, 118, 98, 
	db 110, 109, 44, 46, 47, 0, 0, 0, 32, 0, 
	db 42, 45, 55, 56, 57, 44, 52, 53, 54, 49, 
	db 50, 51, 48, 46, 