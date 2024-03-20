;
; ---------- [ TRANSLATION FROM KEYCODES TO ASCII ] ----------
;

; Acs as an array of ascii characters, when each index in the array in a keycode, which gives you its ascii code.
; keyAsciiArr[keyCode] == asciiCode

	db 27, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
	db 0, 0, 0, 0, 0, 0, 96, 49, 50, 51, 
	db 52, 53, 54, 55, 56, 57, 48, 45, 61, 8, 
	db 9, 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 
	db 'p', 91, 93, 92, 0, 'a', 's', 'd', 'f', 'g', 
	db 'h', 'j', 'k', 'l', 59, 39, 13, 0, 'z', 'x', 
	db 'c', 'v', 'b', 'n', 'm', 44, 46, 47, 0, 0, 
	db 0, 0, 32, 0, 0, 0, 0, 0, 0, 0, 
	db 0, 47, 42, 45, 55, 56, 57, 44, 52, 53, 
	db 54, 49, 50, 51, 48, 46, 