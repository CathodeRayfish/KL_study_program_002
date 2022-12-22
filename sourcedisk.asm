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
	db 0x0d, 'End of loaded data reached. Press any key to change/restart', 0x1d, 0x07

buffer:
	times 128 db 0

times 1024-($-$$) db 0

questionsStart:		;this points to the start location of questions in MEMORY (not on disk) and any questions on any part of a disk (assuming they follow the proper format) can be loaded here

;these questions start at sector 3 and go on for 6 sectors (0000306)

	db 0	;this is here just to add one byte of padding since the main loop always increments bx and this is to account for the intial incement.
	
	db 0x0c, 'Questions from chapter 2 of "How to Learn Greenlandic" by Stian Lybech', 0x0a, 0x0d, '(available at oqa.dk)', 0x0a, 0x0a, 0x0d, 'Press any key to begin...', 0x1d
	
	db 0x0c, '>>Exercise 2.1: Practise sandhi truncativity and say "I am a(n) N"<<', 0x0a, 0x0a, 0x0d		;a section header (or any general message) can be formatted like this (with ASCII lf and cr NOT bel) note that the number of lf (0x0a) will define how many lines are skipped before or after message (with no lf or cr staying on the same line)
	db '{tuttu}N{-u}V{vunga}: ', 0x07, 'tuttuuvunga', 0x07
	db '{igacuq}N{-u}V{vunga}: ', 0x07, 'igasuuvunga', 0x07											;a question can be formatted like this (ASCII bel after question and answer)
	db '{inuk}N{-u}V{vunga}: ', 0x07, 'inuuvunga', 0x07 
	
	db 'Pilluarit! you have completed the first exercise, press any key to move on to the next!', 0x1d, 0x0a, 0x0a, 0x0d	;0x1d will make it so the program doesn't continue until the user has pressed any key.
	
	db 0x0c, '>>Exercise 2.2: Practise the sound rule for /v/<<', 0x0a, 0x0a, 0x0d
	db '{nuuk}V{vunga}: ', 0x07, 'nuuppunga', 0x07
	db '{najugaqaq}V{vunga}: ', 0x07, 'najugaqarpunga', 0x07
	db '{tikit}V{vunga}: ', 0x07, 'tikippunga', 0x07
	
	db 'Pilluarit! you have completed the second exercise, press any key to move on to the next!', 0x1d	;0x1d will make it so the program doesn't continue until the user has pressed any key.

	db 0x0c, '>>Exercise 2.3: Practise the vowel rule<<', 0x0a, 0x0a, 0x0d, 'for this exercerise you will add -u + vunga to each presented word.', 0x0a, 0x0a, 0x0a, 0x0d
	db 'ateq: ', 0x07, 'atiuvunga', 0x07
	db 'ilisimalik: ', 0x07, 'ilisimaliuvunga', 0x07
	db 'qarasaasialerisoq: ', 0x07, 'qarasaasialerisuuvunga', 0x07
	db 'Nuummioq: ', 0x07, 'Nuummiuuvunga', 0x07
	
	db 'Pilluarit! you have completed the third exercise, press any key to move on to the next!', 0x1d
	
	db 0x0c, '>>Exercise 2.4: Practise the vowel rule again, and say "I have an N"<<', 0x0a, 0x0a, 0x0d, 'For this exercise you will add -qaq +vunga to each presented word.', 0x0a, 0x0a, 0x0a, 0x0d
	db 'illu: ', 0x07, 'illoqarpunga', 0x07
	db 'biili: ', 0x07, 'biileqarpunga', 0x07
	db 'nuliaq: ', 0x07, 'nuliaqarpunga', 0x07
	db 'ui: ', 0x07, 'ueqarpunga', 0x07
	db 'meeraq: ', 0x07, 'meeraqarpunga', 0x07
	db 'najugaq: ', 0x07, 'najugaqarpunga', 0x07
	db 'ateq: ', 0x07, 'ateqarpunga', 0x07
	db 'ukioq: ', 0x07, 'ukioqarpunga', 0x07
	
	db 'Pilluarit! you have completed the fourth exercise, press any key to move on to the next!', 0x1d
	
	db 0x0c, '>>Exercise 2.5: Use the vowel rule with weak q-stems<<', 0x0a, 0x0a, 0x0d, 'Say "I move to city" by adding [mut] to city names followed by "nuuppunga".', 0x0a, 0x0a, 0x0a, 0x0d
	db 'Qaanaaq: ', 0x07, 'Qaanaamut nuuppunga', 0x07
	db 'Maniitsoq: ', 0x07, 'Maniitsumut nuuppunga', 0x07
	db 'Qaqortoq: ', 0x07, 'Qaqortumut nuuppunga', 0x07
	db 'Narsaq: ', 0x07, 'Narsamut nuuppunga', 0x07
	db 'Tasiilaq: ', 0x07, 'Tasiilamut nuuppunga', 0x07
	db 'Isortoq: ', 0x07, 'Isortumut nuuppunga', 0x07
	
	db 'Pilluarit! you have completed the fifth exercise, press any key to move on to the next!', 0x1d
	
	db 0x0c, '>>Exercise 2.6: The consonant rule with k-stems<<', 0x0a, 0x0a, 0x0d, 'Say "I live in city" by adding [mi] to city names followed by "najugaqarpunga".', 0x0a, 0x0a, 0x0a, 0x0d
	db 'Nuuk: ', 0x07, 'Nuummi najugaqarpunga', 0x07
	db 'Nanortalik: ', 0x07, 'Nanortalimmi najugaqarpunga', 0x07
	db 'Upernavik: ', 0x07, 'Upernavimmi najugaqarpunga', 0x07
	db 'Arsuk: ', 0x07, 'Arsummi najugaqarpunga', 0x07
	db 'Kulusuk: ', 0x07, 'Kulusummi najugaqarpunga', 0x07
	
	db 'Pilluarit! you have completed the sixth exercise, press any key to move on to the next!', 0x1d

	db 0x0c, '>>Exercise 2.7: City names with plural<<', 0x0a, 0x0a, 0x0d, 'Add the ending [mit] (from N(pl)) to each plural city name, base form provided in parantheses.', 0x0a, 0x0a, 0x0a, 0x0d
	db 'Sisimuit (Sisimioq): ', 0x07, 'Sisimiunit', 0x07
	db 'Paamiut (Paamioq): ', 0x07, 'Paamiunit', 0x07
	db 'Aasiaat (Aasiak): ', 0x07, 'Aasiannit', 0x07
	db 'Qasigiannguit (Qasigiannguaq): ', 0x07, 'Qasigiannguanit', 0x07
	db 'Kapisillit (Kapsilik): ', 0x07, 'Kapisilinnit', 0x07
	
	db 'Pilluarit! You have completed chapter 1 from HOWTO! You can press f5 to return to the address prompt or press enter to continue to the next chapter. (IF next chapter is already loaded it memory, otherwise you will automatically return to address prompt)', 0x1d
	
	times 4096-($-$$) db 0
	
	db 0	;these questions start at sector 9 and go on for 5 sectors (0000905)
	
	db 0x0c, 'Questions from chapter 3 of "How to Learn Greenlandic" by Stian Lybech', 0x0a, 0x0d, '(available at oqa.dk)', 0x0a, 0x0a, 0x0d, 'Press any key to begin...', 0x1d
	
	db 0x0c, '>>Exercise 3.2: Rewrite the sentences to say "can"<<', 0x0a, 0x0a, 0x0d, 'add the affix [sinnaa] to the verb stem of the provided sentences to make the meaning "can vb"', 0x0a, 0x0a, 0x0d, 'Example: Nuummut aallarpunga -> Nuummut aallarsinnaavunga', 0x0a, 0x0a, 0x0a, 0x0d
	db 'Kalaallit Nunaanukarpoq: ', 0x07, 'Kalaallit Nunaanukarsinnaavoq', 0x07
	db 'kalaallisut oqarpoq: ', 0x07, 'kalaallisut oqarsinnaavoq', 0x07
	db 'Koebenhavnimut qimuttuitsorpunga: ', 0x07, 'Koebenhavnimut qimuttuitsorsinnaavunga', 0x07
	db 'timmisartumut ilaavoq: ', 0x07 'timmisartumut ilaasinnavoq', 0x07
	db 'Kangerlussuarmut tikippunga: ', 0x07, 'Kangerlussuarmut tikissinnaavunga', 0x07
	
	db 'Pilluarit! you have completed the first exercise, press any key to move on to the next!', 0x1d
	
	db '>>Exercise 3.3: The fricative rule for /g/<<', 0x0a, 0x0a, 0x0d, 'Use the sg1 causative mood (gama) on the first stem and indicative on the second to say "because vb1, vb2 happened"', 0x0a, 0x0a, 0x0d, 'Example: {qasu}, {sinip} -> qasgugama sinippunga', 0x0a, 0x0a, 0x0a, 0x0d
	db '{suli}V {qasu}V: ', 0x07, 'suligama qasuvunga', 0x07
	db '{tikit}V {iseq}V: ', 0x07, 'tikikkama iserpunga', 0x07
	db '{nuuk}V {aallaq}V: ', 0x07, 'nuukkama aallarpunga', 0x07
	
	db 'Pilluarit! you have completed the second exercise, press any key to move on to the next!', 0x1d
	
	db 0x0c, '>>Exercise 3.4: How to say "not" with V{nngit}V<<', 0x0a, 0x0d, "Use either {nngit}{vik} (didn't at all) or {nngit}{galuar} (didn't actually) on the provided words", 0x0a, 0x0a, 0x0d
	db "Nuummukarpunga {didn't actually}: ", 0x07, 'Nuummukanngikkaluarpunga', 0x07
	db "qimuttuitsorpunga {didn't actually}: ", 0x07, 'qimittuitsunngikkaluarpunga', 0x07
	db "aallarpunga (didn't at all): ", 0x07, 'aallanngivippunga', 0x07
	db "oqarpunga (didn't at all): ", 0x07, 'oqanngivippunga', 0x07
	db "tikippunga (didn't actually): ", 0x07, 'tikinngikkaluarpunga', 0x07
	db "paasivakka (didn't at all): ", 0x07, 'paasinngivippakka', 0x07
	
	db 'Pilluarit! you have completed the third exercise, press any key to move on to the next!', 0x1d
	
	db 0x0c, '>>Exercise 3.5: Play a bit with epenthesis<<', 0x0a, 0x0d, 'Replace the provided senteces mood with contemporative and add "aallarpunga" to change the focus of the sentence.', 0x0a, 0x0a, 0x0a, 0x0d
	db 'timmisartumut ilaavunga: ', 0x07, 'timmisartumut ilaallunga aallarpunga', 0x07
	db 'qimuttuitsorpunga: ', 0x07, 'qimuttuitsorlunga aallarpunga', 0x07
	db 'Nuummukarpunga: ', 0x07, 'Nuummukarlunga aallarpunga', 0x07
	
	db 'Pilluarit! You have completed chapter 2 from HOWTO!', 0x1d
	
	times 9260-($-$$) db 0				;use this for any medium with 1.44 floppy geometry (18 sectors per track)
	;times 6656-($-$$) db 0				;use this for creating img files for QEMU, and other mediums without 1.44m floppy geometry
	
	db 0	;0001906 for noGeometry, 0010106 for real
	
	db 0x0c, 'Questions from chapter 4 of "How to Learn Greenlandic" by Stian Lybech', 0x0a, 0x0d, '(available at oqa.dk)', 0x0a, 0x0a, 0x0d, 'Press any key to begin...', 0x1d

	db 0x0c, '>>Exercise 4.1: V{Tuq}N, the one who Vbs<<', 0x0a, 0x0d, 'add the ending Toq to each word presented (remebering the /T/ rule)', 0x0a, 0x0a, 0x0d
	db 'iga: ', 0x07, 'igasoq', 0x07
	db 'atuaq: ', 0x07, 'atuartoq', 0x07
	db 'suli: ', 0x07, 'sulisoq', 0x07
	db 'aappaluk: ', 0x07, 'aappaluttoq', 0x07
	db 'miki: ', 0x07, 'mikisoq', 0x07
	db 'utaqqi: ', 0x07, 'utaqqisoq', 0x07
	db 'nuuk: ', 0x07, 'nuuttoq', 0x07
	db 'qanoq: ', 0x07, 'qanortoq', 0x07
	
	db 'Pilluarit! you have completed the first exercise, press any key to move on to the next!', 0x1d
	
	db 0x0c, '>>Exercise 4.2: The habitual affix V{Taq}V<<', 0x0a, 0x0d, 'make each presented Vb habitual by adding Taq, use vunga as the ending.', 0x0a, 0x0a, 0x0d
	db 'Atuarfeqarnermut Ingerlatsivimmi {suli}: ', 0x07, 'Atuarfeqarnermut Ingerlatsivimmi sulisarpunga', 0x07
	db 'Nuummi {atuaq}: ', 0x07, 'Nuummi atuartarpunga', 0x07
	db 'Ullaakkut {kaffisoq}: ', 0x07, 'Ullaakkut kaffisortarpunga', 0x07
	db 'Qallunaatut {oqaluk}: ', 0x07, 'Qallunaatut oqaluttarpunga', 0x07
	
	db 'Pilluarit! you have completed the second exercise, press any key to move on to the next!', 0x1d

	db 0x0c, '>>Exercise 4.3: V{Taq}N with other affixes<<', 0x0a, 0x0d, 'Combine each set of morphemes, including Taq, into a word.', 0x0a, 0x0a, 0x0d
	db 'timmi {Taq} {Tuq}: ', 0x07, 'timmisartoq', 0x07
	db 'oqaluk {Taq} {(f)fik}: ', 0x07, 'oqaluttarfik', 0x07
	db 'timersoq {Taq} {Toq}: ', 0x07, 'timersortartoq', 0x07
	db 'timersoq {Taq} {(f)fik}: ', 0x07, 'timersortarfik', 0x07
	db 'tikit {Taq} {(f)fik}: ', 0x07, 'tikittarfik', 0x07
	db 'sinik {Taq} {(f)fik}: ', 0x07, 'sinittarfik', 0x07
	db 'mit {Taq} {(f)fik}: ', 0x07, 'mittarfik', 0x07
	
	db 'Pilluarit! you have completed the third exercise, press any key to move on to the next!', 0x1d

	db 0x0c, '>>Exercise 4.4: Create noun phrases and sentences<<', 0x0a, 0x0d, 'Add Toq, noun endings, and vunga in the right places to form phrases and senteces.', 0x0a, 0x0a, 0x0d
	db '{timmisartoq}, {aappaluk}, {niu}: ', 0x07, 'timmisartumit aappaluttumit niuvunga', 0x07
	db '{tikittarfik}, {miki}, {iseq}: ', 0x07, 'tikittarfimmut mikisumut iserpunga', 0x07
	db '{illu}, {qaqoq}, takulerpara: ', 0x07, 'illu qaqortoq takulerpara', 0x07
	
	db 'Pilluarit! you have completed the fourth exercise, press any key to move on to the next!', 0x1d

	db 0x0c, '>>Exercise 4.5: Use the participial mood<<', 0x0a, 0x0d, 'Turn the second sentece into a subordinate sentence of the first one via the participle mood.', 0x0a, 0x0a, 0x0d
	db 'Takulerpara. Arnaq utaqqivoq: ', 0x07, 'Takulerpara arnaq utaqqisoq', 0x07
	db 'Oqarfigaanga. Suleqatigiippugut: ', 0x07, 'Oqarfigaanga suleqatigiittugut', 0x07
	db 'Oqarpoq. Nuniaffimmi najugaqarputit: ', 0x07, 'Oqarpoq Nuniaffimmi najugaqartutit', 0x07
	db 'Illinuna. Stianimik ateqarputit: ', 0x07, 'Illinuna Stiaminimik ateqartutit', 0x07
	
	db 'Pilluarit! you have completed the fifth exercise, press any key to move on to the next!', 0x1d

	db 0x0c, 'Please note that the upsidown e used to represent schwa is not present in CodePage437. Because of this, /î/ shall be used in its place.', 0x0a, 0x0a, 0x0d, '>>Exercise 4.6: Transitive indicative on î-stems<<', 0x0a, 0x0a, 0x0a, 0x0d
	
	db '{oqarfigî}, {vaatit}: ', 0x07, 'oqarfigaatit', 0x07
	db '{aperî} {vaanga}: ', 0x07, 'aperaanga', 0x07
	
	db 'Pilluarit! you have completed chapter 4 of HOWTO!', 0x1d
	
	times 12288-($-$$) db 0
	
	db 0	;0002507 for noGeometry 0010707 for real
	
	db 0x0c, 'Questions from chapter 5 of "How to Learn Greenlandic" by Stian Lybech', 0x0a, 0x0d, '(available at oqa.dk)', 0x0a, 0x0a, 0x0d, 'Press any key to begin...', 0x1d
	
	db 0x0c, '>>Exercise 5.1: Use the iterative mood<<', 0x0a, 0x0d, 'Add "gaangama" to the first verb and "Taq+vunga" to the second to form an iterative sentence.', 0x0a, 0x0a, 0x0d
	db 'Iteq, kaffisoq: ', 0x07, 'Iteraangama kaffisortarpunga', 0x07
	db 'Sinnartooq, busseq: ', 0x07, 'Sinnartooraangama bussertarpunga', 0x07
	db 'Sulifinnukaq, pisuk: ', 0x07, 'Sulifinnukaraangama pisuttarpunga', 0x07
	
	db 'Pilluarit! you have completed the first exercise, press any key to move on to the next!', 0x1d
	
	db 0x0c, '>>Exercise 5.2: Explore the forms of V{gijaqtuq}V<<', 0x0a, 0x0d, 'Add "gijartor" and either the intransative sg3 or transative sg3/sg3 ending to each presented word to form "subj goes to Vb (obj)".', 0x0a, 0x0a, 0x0d
	db 'kaffisor: ', 0x07, 'kaffisoriartorpoq', 0x07
	db 'sinik: ', 0x07, 'sinikkiartorpoq', 0x07
	db 'ilinniartit: ', 0x07, 'ilinniartikkiartorpaa', 0x07
	db 'iga: ', 0x07, 'igajartorpoq', 0x07
	db 'suli: ', 0x07, 'sulijartorpoq', 0x07
	db 'taku: ', 0x07, 'takujartorpaa', 0x07
	
	db 'Pilluarit! you have completed the second exercise, press any key to move on to the next!', 0x1d
	
	db 0x0c, '>>Exercise 5.3: Use the A rule<<', 0x0a, 0x0d, 'Add -u+voq (he/it is N) to each presented word, remebering the A rule.', 0x0a, 0x0a, 0x0d
	db 'ila: ', 0x07, 'ilaavoq', 0x07
	db 'arnaq: ', 0x07, 'arnaavoq', 0x07
	db 'tassa: ', 0x07, 'tassaavoq', 0x07
	;db 'qarasaasiaq: ', 0x07, 'qarasaasiaavoq', 0x07
	
	db 'Pilluarit! you have completed the third exercise, press any key to move on to the next!', 0x1d
	
	db 0x0c, '>>Exercise 5.4: Practise plural<<', 0x0a, 0x0d, 'Make the presented noun pluaral and add the pl3 ending, (v)vut, to the verb to form a plural sentence', 0x0a, 0x0a, 0x0d
	db 'arnaq, iga: ', 0x07, 'arnat igapput', 0x07
	db 'illu, angi: ', 0x07, 'illut angipput', 0x07
	db 'inuk, sinik: ', 0x07, 'inuit sinipput', 0x07
	db 'aasiak, miki: ', 0x07, 'aasiaat mikipput', 0x07
	db 'inuk 17000-innaq, najugaqaq: ', 0x07, 'inuit 17000-innaat najugaqarput', 0x07
	
	db 'Pilluarit! you have completed the fourth exercise, press any key to move on to the next!', 0x1d
	
	db 0x0c, '>>Exercise 5.5: Verbalising the locative<<', 0x0a, 0x0d, 'Add {it} to the locative of each noun or noun phrase to form a verb, then add indicative sg3 ending to say "it is in N".', 0x0a, 0x0a, 0x0d
	db 'Nuummi: ', 0x07, 'Nuummiippoq', 0x07
	db 'Nuussuarmi: ', 0x07, 'Nuussuarmiippoq', 0x07
	db 'Qinngutsinni: ', 0x07, 'Qinngutsinniippoq', 0x07
	db 'Nuussuup kitaani: ', 0x07, 'Nuussuup kitaaniippoq', 0x07
	db 'Nuussuup kangiani: ', 0x07, 'Nuussuup kangianiippoq', 0x07
	db 'Nunaffiup saninnguani: ', 0x07, 'Nunaffiup saninnguaniippoq', 0x07
	db 'Nuup kangerluata qinnguani: ', 0x07, 'Nuup kangerluata qinnguaniippoq.', 0x07
	
	db 'Pilluarit! you have completed the fifth exercise, press any key to move on to the next!', 0x1d
	
	db 0x0c, '>>Exercise 5.6: Comparison<<', 0x0a, 0x0d, 'For each presented list add {mit} to the second noun then add {neru}+{voq} to the verb to say "N1 Vb more than N2".', 0x0a, 0x0a, 0x0d
	db 'illu, biili, {angi}: ', 0x07, 'illu biilimit angineruvoq', 0x07
	db 'Nuup qeqqa, mittarfik, {ungasik}: ', 0x07, 'Nuup qeqqa mittarfimmit ungasinneruvoq', 0x07
	db 'Nuuk, Aalborgi, {miki}: ', 0x07, 'Nuuk Aalborgimit mikineruvoq', 0x07
	db 0x0a, 0x0a, 0x0d, 'Now use "nersarî" (N Vb most of Ns), remeber to use the transative pl3/sg3 ending {vaat}.', 0x0a, 0x0a, 0x0d, 0x1d
	db 'Nuuk, Kalaallit Nunaata illoqarfiisa, {angi}: ', 0x07, 'Nuuk Kalaallit Nunaata illoqarfiisa anginersaraat', 0x07
	db 'Qinngorput, Nuup ilaasa, {ungasik}: ', 0x07, 'Qinngorput Nuup ilaasa ungasinnersaraat', 0x07
	db 'illuga, illut, {miki}: ', 0x07, 'illuga illut mikinersaraat', 0x07
	
	db 'Pilluarit! you have completed the sixth exercise, press any key to move on to the next!', 0x1d
	
	db 0x0c, '>>Exercise 5.7: Saying "there is N"<<', 0x0a, 0x0d, 'Put the first noun in locative case then add {qar}+{voq} to the second noun to say "there is N2 in/on N1".', 0x0a, 0x0a, 0x0d
	db 'igaffik, arnaq: ', 0x07, 'igafimmi arnaqarpoq', 0x07
	db 'aqqusineq, biili: ', 0x07, 'aqqusinermi biileqarpoq', 0x07
	db 'immikkoortoq kingulleq, oqaluttuaq: ', 0x07, 'immikkoortumi kingullermi oqaluttuaqarpoq', 0x07
	db 'Nunaffiup saninngua, unittarfik: ', 0x07, 'Nunaffiup saninnguani unittarfeqarpoq', 0x07
	;db 'Nuup Kangerluata eqqaa, puisi: ', 0x07, 'Nuup Kangerluata eqqaani puiseqarpoq', 0x07
	
	db 'Pilluarit! you have completed chapter 5 of HOWTO!', 0x1d
	
	times 18432-($-$$) db 0
	;times 15872-($-$$) db 0	;leftover from old noGeometry versions
	
	db 0	;0003206 for noGeometry 0100106 for real	(In CHS addressing sector counts start at 1 and all else starts at 0... I have no idea why.)
	
	db 0x0c, 'Questions from chapter 6 of "How to Learn Greenlandic" by Stian Lybech', 0x0a, 0x0d, '(available at oqa.dk)', 0x0a, 0x0a, 0x0d, 'Press any key to begin...', 0x1d

	db 0x0c, '>>Exercise 6.1: Examples of the î rule<<', 0x0a, 0x0d, 'Combine the presented lists of morphemes, remebering the î rule.', 0x0a, 0x0a, 0x0d
	db '{angutî}{t}: ', 0x07, 'angutit', 0x07
	db '{angutî}{-qaq}{voq}: ', 0x07, 'anguteqarpoq', 0x07
	db '{angutî}{-u}{vunga}: ', 0x07, 'angutaavunga', 0x07
	db '{angutî}: ', 0x07, 'angut', 0x07
	db '{inî}{t}: ', 0x07, 'init', 0x07
	db '{inî}{-qaq}{voq}: ', 0x07, 'ineqarpoq', 0x07
	db '{inî}{-a}: ', 0x07, 'inaa', 0x07
	db '{inî}{-i}: ', 0x07, 'inai', 0x07
	db '{inî}: ', 0x07, 'ini', 0x07
	db '{siunnersortî}{t}: ', 0x07, 'siunnersortit', 0x07
	db '{siunnersortî}: ', 0x07, 'siunnersorti', 0x07
	db '{siunnersortî}{-u}{vunga}: ', 0x07, 'siunnersortaavunga', 0x07
	db '{pequtî}: ', 0x07, 'pequt', 0x07
	db '{pequtî}{t}: ', 0x07, 'pequtit', 0x07
	db '{pequtî}{-kka}: ', 0x07, 'pequtikka', 0x07
	db '{atuagaatî}{-kka}: ', 0x07, 'atuagaatikka', 0x07
	
	db 'Pilluarit! you have completed the first exercise, press any key to move on to the next!', 0x1d

	db 0x0c, '>>Exercise 6.2: Indicative endings on verbal î stems<<', 0x0a, 0x0d, 'Combine the presented lists of morphemes, remebering the î rule and how indicative endings and how î interact.', 0x0a, 0x0a, 0x0d
	db '{nuannarî}{vara}: ', 0x07, 'nuannaraara', 0x07
	db '{nuannarî}{vaa}: ', 0x07, 'nuannaraa', 0x07
	db '{mikî}{-qî}{voq}: ', 0x07, 'mikeqaaq', 0x07
	db '{angî}{-qî}{(v)vut}: ', 0x07, 'angeqaat', 0x07
	
	db 'Pilluarit! you have completed the second exercise, press any key to move on to the next!', 0x1d

	
	db 0x0c, '>>Exercise 6.3: The t rule and the î rule<<', 0x0a, 0x0d, 'Combine the presented lists of morphemes, remebering the î rule and the t rule.', 0x0a, 0x0a, 0x0d
	db '{oqalukTî}: ', 0x07, 'oqalutsi', 0x07
	db '{oqalukTî}{-u}{vunga}: ', 0x07, 'oqaluttaavunga', 0x07
	db '{najoqTî}: ', 0x07, 'najorti', 0x07
	db '{najoqTî}{-u}{vunga}: ', 0x07, 'najortaavunga', 0x07
	
	db 'Pilluarit! you have completed the third exercise, press any key to move on to the next!', 0x1d
	
	db 0x0c, '>>Exercise 6.4: Add morphemes to t(î) stems<<', 0x0a, 0x0d, 'add presented morphemes and endings to the stem "nassiutî".', 0x0a, 0x0a, 0x0d
	db '{vaa}: ', 0x07, 'nassiuppaa', 0x07
	db '{neqar}{(v)vut}: ', 0x07, 'nassiunneqarput', 0x07
	db '{-qqu}{vara}: ', 0x07, 'nassiuteqquara', 0x07
	db '{Tariaqar}{vakka}: ', 0x07, 'nassiuttariaqarpakka', 0x07
	
	db 'Pilluarit! you have completed the fourth exercise, press any key to move on to the next!', 0x1d

	db 0x0c, '>>Exercise 6.5: Use the numerals.<<', 0x0a, 0x0d, 'Translate each presented English phrase to Greenlandic, including written Greenlandic numbers.', 0x0a, 0x0a, 0x0d
	
	db 0x0a, 0x0a, 0x0d, 'Remeber if the numeral is applying to a noun incorperated in a verb phrase then it must be in instrumental case (mik/nik). Use the glossary of HowTo to find the translations for words that may be needed.', 0x0a, 0x0a, 0x0a, 0x0d

	db 'There are three rooms: ', 0x07, 'pingasunik ineqarpoq', 0x07
	db 'There is just one apartment: ', 0x07, 'ataasiinnarmik inissiaqarpoq', 0x07
	db 'There are two mountains: ', 0x07, 'marlunnik qaqqaqarpoq', 0x07
	db 'I see three mountains: ', 0x07, 'qaqqat pingasut takuakka', 0x07
	db 'There are two beds in the bedroom: ', 0x07, 'sinittarfimmi marlunnik siniffeqarpoq', 0x07
	db 'There is just one kitcehn in the new apartment: ', 0x07, 'inissiartaami ataassinnarmik igafeqarpoq', 0x07
	db 'There are five chairs in the living room: ', 0x07, 'insersuarmi tallimanik issiaveqarpoq ', 0x07
	db 'There is just one bathroom in my new apartment', 0x07, 'inissiartaara ataasiinnaq uffeqarfeqarpoq', 0x07
	db 'The small apartment has just two rooms', 0x07, 'inissiaaraq marluinnarnik ineqarpoq', 0x07
	db 'I lived in Nuniaffik for just one month', 0x07, 'qaammat ataasiinnaq Nuniaffimmi najugaqarpunga', 0x07
	
	db 'Pilluarit! you have completed chapter 6 of HOWTO!', 0x1d
	
	db 0x0c, 'Pilluarit!! you have completed all the default questions currently in the program disk. As of current there is nothing else on this disk but you can always try making your own disk! If you have any questions about the program or content for it you can inquire on Discord CathodeRayfish#3397.', 0x1d
	
	
	;times 368640 -($-$$) db 0	;for 5.25 360k (geometry NOT AT ALL SUPPORTED right now)
	times 1474560-($-$$) db 0   ;fill all remaning bytes to reach capacity of 1.44MB floppy disk for compatibility reasons.
