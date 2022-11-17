;Version 0.1

BITS 16
CPU 8086
[org 0x7c00]
mov [diskNum], dl

jmp 0x0000:origin

origin:

clc

xor ax, ax  	;just to be safe clearing all the registers and setting up memory based on what stackOverflow says to do
mov es, ax
mov ds, ax
mov ss, ax
mov sp, 0x7c00
mov bp, sp
xor bx, bx
xor cx, cx
xor si, si
xor di, di

mov bx, 0x7e00	;the program's base data (ajoraluartumik) takes up more than 512 byte 1 sector so this just loads another sector after the boot sector.
mov ah, 0x02
mov cl, 2
mov al, 1
int 0x13

start:

xor cx, cx
mov bx, message
call printString
	
xor ah, ah		;get 10s value for ch register (cylinder to read)
int 0x16
mov ah, 0x0e
int 0x10
sub al, 48
mov bl, 10
mul bl
add ch, al
	
xor ah, ah		;get 1s value for ch register
int 0x16
mov ah, 0x0e
int 0x10
sub al, 48
add ch, al

xor ah, ah		;get value for dh register (head to read from)
int 0x16
mov ah, 0x0e
int 0x10
sub al, 48
mov dh, al

xor ah, ah		;get 10s value for cl register (track to read from)
int 0x16
mov ah, 0x0e
int 0x10
sub al, 48
mov bl, 10
mul bl
add cl, al
	
xor ah, ah		;get 1s value for cl register
int 0x16
mov ah, 0x0e
int 0x10
sub al, 48
add cl, al

xor ah, ah		;get 10s value for al register (number of sectors to read)
int 0x16
mov ah, 0x0e
int 0x10
sub al, 48
mov bl, 10
mul bl
mov bh, al
	
xor ah, ah		;get 1s value for al register
int 0x16
mov ah, 0x0e
int 0x10
sub al, 48
add al, bh

mov dl, [diskNum]
mov ah, 0x02
mov bx, 0x8000
int 0x13		;load data from disk using above user defined parametres
jnc readGood
	mov bx, readError
	call printString
	
readGood:

xor ah, ah		;this small segment adds a terminating 0x1c after the entirety of the data that user had loaded to ram. This is to prevent a buffer overflow and send user to address prompt when they have finished all loaded questions.
mov cx, 512
mul cx
add bx, ax
mov al, 0x1c
mov [bx], al

mov bx, questionsStart	;bx starts here and goes up based on strings; it should NEVER have its value changed without push/pop
mainLoop:
	call nextLine
	inc bx
	call printString
	call userInput
	call nextLine
	inc bx
	call compare
	push bx
	cmp ah, 1
	je correct
	mov bx, incorrectMessage
	call printString
	pop bx
	call printString
	jmp mainLoop

	correct:
		mov bx, correctMessage
		call printString
		pop bx
		jmp mainLoop


printString:   
	mov ah, 0x0e
	printStringLoop:
		mov al, [bx]
		cmp al, 0x07
		je printEnd
		cmp al, 0x1c
		je studyEnd
		cmp al, 0x1d
		je keyPress
		cmp al, 0x0c
		je clearScreen
		int 0x10
		inc bx
		jmp printStringLoop
		keyPress:
			xor ah, ah
			int 0x16
			jmp printExtraEnd
		clearScreen:
			xor ah, ah
			mov al, 0x03
			int 0x10
			jmp printExtraEnd
			
		printExtraEnd:
			inc bx
			jmp printString
		
		printEnd:
			ret
			
nextLine:
	mov ah, 0x0e
	mov al, 0x0a
	int 0x10
	mov al, 0x0a
	int 0x10
	mov al, 0x0d
	int 0x10
	ret
	
userInput:
	mov di, buffer
	xor cx, cx
	keyboardLoop:
		xor ah, ah
		int 0x16
		cmp ah, 0x3f
		je start
		
		cmp al, 0x0d
		je enterKey
		cmp al, 0x08
		je backspaceKey
		
		cmp cx, 127			;ensure that user does not enter more keys than buffer length
		je keyboardLoop
		inc cx
		
		mov [di], al		;write ASCII value to keyboard buffer
		inc di
		mov ah, 0x0e
		int 0x10			;print ASCII character on screen
		jmp keyboardLoop
		
	enterKey:
		inc di
		mov al, 0x07
		mov [di], al
		ret
	
	backspaceKey:
		cmp cx, 0
		je keyboardLoop
	    dec di
		dec cx
			push ax			;this whole indented section of code is literally just to handle a backspace called at column 0
			push bx
			push cx
			xor bh, bh
			mov ah, 0x03
			int 0x10
			cmp dl, 0
			jne noMoveUp
			sub dh, 1
			mov dl, 79
			mov ah, 0x02
			int 0x10
		mov ah, 0x0a
		xor al, al
		xor bx, bx
		mov cx, 1
        xor al, al
		int 0x10
			pop cx
			pop bx
			pop ax
			jmp keyboardLoop
			noMoveUp:
			pop cx
			pop bx
			pop ax
		mov ah, 0x0e
		mov al, 0x08
		int 0x10
        xor al, al
		int 0x10
		mov al, 0x08
		int 0x10
        jmp keyboardLoop

compare:
	push bx
	mov di, buffer
	compareLoop:
		mov al, [bx]
		mov cl, [di]
		cmp al, 0x07
		je compareTrue
		cmp al, cl
		;jne compareFalse		;Use this line to enable case-sensitive comparing.
		je charCompareGood		;Use this line and all indented items below to enable non-case-sensitive comparing.
			add al, 32
			cmp al, cl
			je charCompareGood
			sub al, 64
			cmp al, cl
			je charCompareGood
			jmp compareFalse
		charCompareGood:
		inc bx
		inc di
		jmp compareLoop
	compareFalse:
	xor ah, ah
	pop bx
	ret
	compareTrue:
	mov ah, 1
	add sp, 2
	ret
	
studyEnd:
	mov bx, endMessage
	call printString
	jmp start
	
diskNum:
	db 0

times 510-($-$$) db 0
dw 0xaa55

message:
	db 0x0c, 'Welcome, please type the CHS address followed by the number of sectors to read. Refer to a program manual for which addresses correspond to which question sets.(NO SPACES)', 0x0a, 0x0a, 0x0d, 0x07
	
readError:
	db 'Disk read error!', 0x07

correctMessage:
	db 'Correct!', 0x07
	
incorrectMessage:
	db 'Incorrect. The correct answer was: ', 0x07

endMessage:
	db 0x0d, 'End of set reached. Press any key to change/restart', 0x1d, 0x07

buffer:
	times 128 db 0

times 1024-($-$$) db 0

questionsStart:		;this points to the start location of questions in MEMORY (not on disk) and any questions on any part of a disk (assuming they follow the proper format) can be loaded here

;these questions start at sector 3 and go on for 6 sectors (0000306)

	db 0	;this is here just to add one byte of padding since the main loop always increments bx and this is to account for the intial incement.
	
	db 0x0c, 'Questions from chapter 1 of "How to Learn Greenlandic" by Stian Lybech', 0x0a, 0x0d, '(available at oqa.dk)', 0x0a, 0x0a, 0x0d, 'Press any key to begin...', 0x1d
	
	db 0x0c, '>>Exercise 1.1: Practice sandhi truncativity and say "I am a(n) N"<<', 0x0a, 0x0a, 0x0d		;a section header (or any general message) can be formatted like this (with ASCII lf and cr NOT bel) note that the number of lf (0x0a) will define how many lines are skipped before or after message (with no lf or cr staying on the same line)
	db '{tuttu}N{-u}V{vunga}: ', 0x07, 'tuttuuvunga', 0x07
	db '{igacuq}N{-u}V{vunga}: ', 0x07, 'igasuuvunga', 0x07											;a question can be formatted like this (ASCII bel after question and answer)
	db '{inuk}N{-u}V{vunga}: ', 0x07, 'inuuvunga', 0x07 
	
	db 'Pilluarit! you have completed the first exercise, press any key to move on to the next!', 0x1d, 0x0a, 0x0a, 0x0d	;0x1d will make it so the program doesn't continue until the user has pressed any key.
	
	db 0x0c, '>>Exercise 1.2: Practice the sound rule for /v/<<', 0x0a, 0x0a, 0x0d
	db '{nuuk}V{vunga}: ', 0x07, 'nuuppunga', 0x07
	db '{najugaqaq}V{vunga}: ', 0x07, 'najugaqarpunga', 0x07
	db '{tikit}V{vunga}: ', 0x07, 'tikippunga', 0x07
	
	db 'Pilluarit! you have completed the second exercise, press any key to move on to the next!', 0x1d	;0x1d will make it so the program doesn't continue until the user has pressed any key.

	db 0x0c, '>>Exercise 1.3: Practice the vowel rule<<', 0x0a, 0x0a, 0x0d, 'for this exercerise you will add -u + vunga to each presented word.', 0x0a, 0x0a, 0x0a, 0x0d
	db 'ateq: ', 0x07, 'atiuvunga', 0x07
	db 'ilisimalik: ', 0x07, 'ilisimaliuvunga', 0x07
	db 'qarasaasialerisoq: ', 0x07, 'qarasaasialerisuuvunga', 0x07
	db 'Nuummioq: ', 0x07, 'Nuummiuuvunga', 0x07
	
	db 'Pilluarit! you have completed the third exercise, press any key to move on to the next!', 0x1d
	
	db 0x0c, '>>Exercise 1.4: Practice the vowel rule again, and say "I have an N"<<', 0x0a, 0x0a, 0x0d, 'For this exercise you will add -qaq +vunga to each presented word.', 0x0a, 0x0a, 0x0a, 0x0d
	db 'illu: ', 0x07, 'illoqarpunga', 0x07
	db 'biili: ', 0x07, 'biileqarpunga', 0x07
	db 'nuliaq: ', 0x07, 'nuliaqarpunga', 0x07
	db 'ui: ', 0x07, 'ueqarpunga', 0x07
	db 'meeraq: ', 0x07, 'meeraqarpunga', 0x07
	db 'najugaq: ', 0x07, 'najugaqarpunga', 0x07
	db 'ateq: ', 0x07, 'ateqarpunga', 0x07
	db 'ukioq: ', 0x07, 'ukioqarpunga', 0x07
	
	db 'Pilluarit! you have completed the fourth exercise, press any key to move on to the next!', 0x1d
	
	db 0x0c, '>>Exercise 1.5: Use the vowel rule with weak q-stems<<', 0x0a, 0x0a, 0x0d, 'Say "I move to city" by adding [mut] to city names followed by "nuuppunga".', 0x0a, 0x0a, 0x0a, 0x0d
	db 'Qaanaaq: ', 0x07, 'Qaanaamut nuuppunga', 0x07
	db 'Maniitsoq: ', 0x07, 'Maniitsumut nuuppunga', 0x07
	db 'Qaqortoq: ', 0x07, 'Qaqortumut nuuppunga', 0x07
	db 'Narsaq: ', 0x07, 'Narsamut nuuppunga', 0x07
	db 'Tasiilaq: ', 0x07, 'Tasiilamut nuuppunga', 0x07
	db 'Isortoq: ', 0x07, 'Isortumut nuuppunga', 0x07
	
	db 'Pilluarit! you have completed the fifth exercise, press any key to move on to the next!', 0x1d
	
	db 0x0c, '>>Exercise 1.6: The consonant rule with k-stems<<', 0x0a, 0x0a, 0x0d, 'Say "I live in city" by adding [mi] to city names followed by "najugaqarpunga".', 0x0a, 0x0a, 0x0a, 0x0d
	db 'Nuuk: ', 0x07, 'Nuummi najugaqarpunga', 0x07
	db 'Nanortalik: ', 0x07, 'Nanortalimmi najugaqarpunga', 0x07
	db 'Upernavik: ', 0x07, 'Upernavimmi najugaqarpunga', 0x07
	db 'Arsuk: ', 0x07, 'Arsummi najugaqarpunga', 0x07
	db 'Kulusuk: ', 0x07, 'Kulusummi najugaqarpunga', 0x07
	
	db 'Pilluarit! you have completed the sixth exercise, press any key to move on to the next!', 0x1d

	db 0x0c, '>>Exercise 1.7: City names with plural<<', 0x0a, 0x0a, 0x0d, 'Add the ending [mit] (from N(pl)) to each plural city name, base form provided in parantheses.', 0x0a, 0x0a, 0x0a, 0x0d
	db 'Sisimuit (Sisimioq): ', 0x07, 'Sisimiunit', 0x07
	db 'Paamiut (Paamioq): ', 0x07, 'Paamiunit', 0x07
	db 'Aasiaat (Aasiak): ', 0x07, 'Aasiannit', 0x07
	db 'Qasigiannguit (Qasigiannguaq): ', 0x07, 'Qasigiannguanit', 0x07
	db 'Kapisillit (Kapsilik): ', 0x07, 'Kapisilinnit', 0x07
	
	db 'Pilluarit! You have completed chapter 1 from HOWTO! You can press f5 to return to the address prompt or press enter to continue to the next chapter. (IF next chapter is already loaded it memory, otherwise you will automatically return to address prompt)', 0x1d
	
	times 4096-($-$$) db 0
	
	db 0	;these questions start at sector 9 and go on for 5 sectors (0000905)
	
	db 0x0c, 'Questions from chapter 2 of "How to Learn Greenlandic" by Stian Lybech', 0x0a, 0x0d, '(available at oqa.dk)', 0x0a, 0x0a, 0x0d, 'Press any key to begin...', 0x1d
	
	db 0x0c, '>>Exercise 2.2: Rewrite the sentences to say "can"<<', 0x0a, 0x0a, 0x0d, 'add the affix [sinnaa] to the verb stem of the provided sentences to make the meaning "can vb"', 0x0a, 0x0a, 0x0d, 'Example: Nuummut aallarpunga -> Nuummut aallarsinnaavunga', 0x0a, 0x0a, 0x0a, 0x0d
	db 'Kalaallit Nunaanukarpoq: ', 0x07, 'Kalaallit Nunaanukarsinnaavoq', 0x07
	db 'kalaallisut oqarpoq: ', 0x07, 'kalaallisut oqarsinnaavoq', 0x07
	db 'Koebenhavnimut qimuttuitsorpunga: ', 0x07, 'Koebenhavnimut qimuttuitsorsinnaavunga', 0x07
	db 'timmisartumut ilaavoq: ', 0x07 'timmisartumut ilaasinnavoq', 0x07
	db 'Kangerlussuarmut tikippunga: ', 0x07, 'Kangerlussuarmut tikissinnaavunga', 0x07
	
	db 'Pilluarit! you have completed the first exercise, press any key to move on to the next!', 0x1d
	
	db '>>Exercise 2.3: The fricative rule for /g/<<', 0x0a, 0x0a, 0x0d, 'Use the sg1 causative mood (gama) on the first stem and indicative on the second to say "because vb1, vb2 happened"', 0x0a, 0x0a, 0x0d, 'Example: {qasu}, {sinip} -> qasgugama sinippunga', 0x0a, 0x0a, 0x0a, 0x0d
	db '{suli}V {qasu}V: ', 0x07, 'suligama qasuvunga', 0x07
	db '{tikit}V {iseq}V: ', 0x07, 'tikikkama iserpunga', 0x07
	db '{nuuk}V {aallaq}V: ', 0x07, 'nuukkama aallarpunga', 0x07
	
	db 'Pilluarit! you have completed the second exercise, press any key to move on to the next!', 0x1d
	
	db 0x0c, '>>Exercise 2.4: How to say "not" with V{nngit}V<<', 0x0a, 0x0d, "Use either {nngit}{vik} (didn't at all) or {nngit}{galuar} (didn't actually) on the provided words", 0x0a, 0x0a, 0x0d
	db "Nuummukarpunga {didn't actually}: ", 0x07, 'Nuummukanngikkaluarpunga', 0x07
	db "qimuttuitsorpunga {didn't actually}: ", 0x07, 'qimittuitsunngikkaluarpunga', 0x07
	db "aallarpunga (didn't at all): ", 0x07, 'aallanngivippunga', 0x07
	db "oqarpunga (didn't at all): ", 0x07, 'oqanngivippunga', 0x07
	db "tikippunga (didn't actually): ", 0x07, 'tikinngikkaluarpunga', 0x07
	db "paasivakka (didn't at all): ", 0x07, 'paasinngivippakka', 0x07
	
	db 'Pilluarit! you have completed the third exercise, press any key to move on to the next!', 0x1d
	
	db 0x0c, '>>Exercise 2.5: Play a bit with epenthesis<<', 0x0a, 0x0d, 'Replace the provided senteces mood with contemporative and add "aallarpunga" to change the focus of the sentence.', 0x0a, 0x0a, 0x0a, 0x0d
	db 'timmisartumut ilaavunga: ', 0x07, 'timmisartumut ilaallunga aallarpunga', 0x07
	db 'qimuttuitsorpunga: ', 0x07, 'qimuttuitsorlunga aallarpunga', 0x07
	db 'Nuummukarpunga: ', 0x07, 'Nuummukarlunga aallarpunga', 0x07
	
	db 'Pilluarit! You have completed chapter 2 from HOWTO!', 0x1d
	
	times 9261-($-$$) db 0				;use this for any medium with 1.44 floppy geometry (18 sectors per track)
	;times 6656-($-$$) db 0				;use this for creating img files for QEMU, and other mediums without 1.44m floppy geometry
	
	db 0x0c, 'Questions from chapter 3 of "How to Learn Greenlandic" by Stian Lybech', 0x0a, 0x0d, '(available at oqa.dk)', 0x0a, 0x0a, 0x0d, 'Press any key to begin...', 0x1d

	db 0x0c, '>>Exercise 3.1: V{Tuq}N, the one who Vbs<<', 0x0a, 0x0d, 'add the ending Toq to each word presented (remebering the /T/ rule)', 0x0a, 0x0a, 0x0d
	db 'iga: ', 0x07, 'igasoq', 0x07
	db 'atuaq: ', 0x07, 'atuartoq', 0x07
	db 'suli: ', 0x07, 'sulisoq', 0x07
	db 'aappaluk: ', 0x07, 'aappaluttoq', 0x07
	db 'miki: ', 0x07, 'mikisoq', 0x07
	db 'utaqqi: ', 0x07, 'utaqqisoq', 0x07
	db 'nuuk: ', 0x07, 'nuuttoq', 0x07
	db 'qanoq: ', 0x07, 'qanortoq', 0x07
	
	db 'Pilluarit! you have completed the first exercise, press any key to move on to the next!', 0x1d
	
	db 0x0c, '>>Exercise 3.2: The habitual affix V{Taq}V<<', 0x0a, 0x0d, 'make each presented Vb habitual by adding Taq, use vunga as the ending.', 0x0a, 0x0a, 0x0d
	db 'Atuarfeqarnermut Ingerlatsivimmi {suli}: ', 0x07, 'Atuarfeqarnermut Ingerlatsivimmi sulisarpunga', 0x07
	db 'Nuummi {atuaq}: ', 0x07, 'Nuummi atuartarpunga', 0x07
	db 'Ullaakkut {kaffisoq}: ', 0x07, 'Ullaakkut kaffisortarpunga', 0x07
	db 'Qallunaatut {oqaluk}: ', 0x07, 'Qallunaatut oqaluttarpunga', 0x07
	
	db 'Pilluarit! you have completed the second exercise, press any key to move on to the next!', 0x1d

	db 0x0c, '>>Exercise 3.3: V{Taq}N with other affixes<<', 0x0a, 0x0d, 'Combine each set of morphemes, including Taq, into a word.', 0x0a, 0x0a, 0x0d
	db 'timmi {Taq} {Tuq}: ', 0x07, 'timmisartoq', 0x07
	db 'oqaluk {Taq} {(f)fik}: ', 0x07, 'oqaluttarfik', 0x07
	db 'timersoq {Taq} {Toq}: ', 0x07, 'timersortartoq', 0x07
	db 'timersoq {Taq} {(f)fik}: ', 0x07, 'timersortarfik', 0x07
	db 'tikit {Taq} {(f)fik}: ', 0x07, 'tikittarfik', 0x07
	db 'sinik {Taq} {(f)fik}: ', 0x07, 'sinittarfik', 0x07
	db 'mit {Taq} {(f)fik}: ', 0x07, 'mittarfik', 0x07
	
	db 'Pilluarit! you have completed the third exercise, press any key to move on to the next!', 0x1d

	db 0x0c, '>>Exercise 3.4: Create noun phrases and sentences<<', 0x0a, 0x0d, 'Add Toq, noun endings, and vunga in the right places to form phrases and senteces.', 0x0a, 0x0a, 0x0d
	db '{timmisartoq}, {aappaluk}, {niu}: ', 0x07, 'timmisartumit aappaluttumit niuvunga', 0x07
	db '{tikittarfik}, {miki}, {iseq}: ', 0x07, 'tikittarfimmut mikisumut iserpunga', 0x07
	db '{illu}, {qaqoq}, takulerpara: ', 0x07, 'illu qaqortoq takulerpara', 0x07
	
	db 'Pilluarit! you have completed the fourth exercise, press any key to move on to the next!', 0x1d

	db 0x0c, '>>Exercise 3.5: Use the participial mood<<', 0x0a, 0x0d, 'Turn the second sentece into a subordinate sentence of the first one via the participle mood.', 0x0a, 0x0a, 0x0d
	db 'Takulerpara. Arnaq utaqqivoq: ', 0x07, 'Takulerpara arnaq utaqqisoq', 0x07
	db 'Oqarfigaanga. Suleqatigiippugut: ', 0x07, 'Oqarfigaanga suleqatigiittugut', 0x07
	db 'Oqarpoq. Nuniaffimmi najugaqarputit: ', 0x07, 'Oqarpoq Nuniaffimmi najugaqartutit', 0x07
	db 'Illinuna. Stianimik ateqarputit: ', 0x07, 'Illinuna Stiaminimik ateqartutit', 0x07
	
	db 'Pilluarit! you have completed the fifth exercise, press any key to move on to the next!', 0x1d

	db 0x0c, 'Please note that the upsidown e used to represent schwa is not present in CodePage437. Because of this, /î/ shall be used in its place.', 0x0a, 0x0a, 0x0d, '>>Exercise 3.6: Transitive indicative on î-stems<<', 0x0a, 0x0a, 0x0a, 0x0d
	
	db '{oqarfigî}, {vaatit}: ', 0x07, 'oqarfigaatit', 0x07
	db '{aperî} {vaanga}: ', 0x07, 'aperaanga', 0x07
	
	db 'Pilluarit! you have completed chapter 4 of HOWTO!', 0x1d

	
	db 0x0c, 'Pilluarit!! you have completed all the default questions currently in the program disk. As of current there is nothing else on this disk but you can always try making your own disk! If you have any questions about the program or content for it you can inquire on Discord CathodeRayfish#3397.', 0x1d
	
	times 1474560-($-$$) db 0   ;fill all remaning bytes to reach capacity of 1.44MB floppy disk for compatibility reasons.
