[org 0x0100]

jmp start

; ================= DATA SECTION =================

; --- Screens ---
main_1: db '           *************             ',0
main_2: db '        ****************** *******      ',0
main_3: db '       *******       *****     **       ',0
main_4: db '       ******        *****              ',0
main_5: db '        ********         *****          ',0
main_6: db '         ***************** **           ',0
main_7: db '              *****************        ',0
main_8: db '  ******                 ********       ',0
main_9: db ' ***********               ********     ',0
main_10: db ' ****      *****             *******     ',0
main_11: db ' *****        *********      *******     ',0
main_12: db '  ********                  *******      ',0
main_13: db '    **********         **********       ',0
main_14: db '        ***********************         ',0
main_15: db '               ****  **                 ',0
main_16: db' ____              _           ____                      ',0
main_17: db'/ ___| _ __   __ _| | _____   / ___| __ _ _ __ ___   ___ ',0
main_18: db'\___ \| `_ \ / _` | |/ / _ \ | |  _ / _` | `_ ` _ \ / _ \',0
main_19: db' ___) | | | | (_| |   <  __/ | |_| | (_| | | | | | |  __/',0
main_20: db'|____/|_| |_|\__,_|_|\_\___|  \____|\__,_|_| |_| |_|\___|',0

; --- End Screen ---
main_21: db ' _____   ___  ___  ___ _____   _____  _   _ ___________  ',0
main_22: db '|  __ \ / _ \ |  \/  ||  ___| |  _  || | | |  ___| ___ \ ',0
main_23: db '| |  \// /_\ \| .  . || |__   | | | || | | | |__ | |_/ / ',0
main_24: db '| | __ |  _  || |\/| ||  __|  | | | || | | |  __||    /  ',0
main_25: db '| |_\ \| | | || |  | || |___  \ \_/ /\ \_/ / |___| |\ \  ',0
main_26: db ' \____/\_| |_/\_|  |_/\____/   \___/  \___/\____/\_| \_| ',0
box_top: db '+----------------------+', 0
box_mid: db '|      SCORE:          |', 0
box_bot: db '+----------------------+', 0
btn1_top: db '  _____________  ', 0
btn1_mid: db ' |   [SPACE]   | ', 0
btn1_txt: db ' |   RESTART   | ', 0
btn1_bot: db ' |_____________| ', 0
btn2_top: db '  _____________  ', 0
btn2_mid: db ' |    [ESC]    | ', 0
btn2_txt: db ' |    EXIT     | ', 0
btn2_bot: db ' |_____________| ', 0

; --- Game Variables ---
scorestr: db 'Score: ',0
line: db '--------------------------------------------------------------------------------',0
score: dw 0
Apple: db 'b',0
seed: dw 0
r_row: db 0
r_col: db 0
snake: db '     ',0 ; Initial snake body char for print
size: dw 5

; Snake Logic Variables
Tail_Row: db 12
Tail_Col: db 37
Head_Row: db 12
Head_Col: db 41
nextDirection: db 'd'  ; Current direction
game_over_flag: db 0   ; 0 = running, 1 = over
tick_count: dw 0
move_snake: db 0       ; Flag set by timer to update game

; ISR Storage
old_isr_kb: dd 0
old_isr_tm: dd 0

; ================= MAIN PROGRAM =================
start:
    call hook_keyboard
    call hook_timer

Main_Menu_Loop:
    call clrscr
    call Starting_Screen
    
    mov byte [nextDirection], 0 ; Clear buffer
wait_start_key:
    mov ah, 0
    int 16h

Start_New_Game:
    call Init_Game_State
    call clrscr
    call Draw_Game_UI

    mov ax, 0xb800
    mov es, ax
    mov di, 1994       
    
    mov cx, 5
draw_init_snake:
    ; *** CHANGED: Use bright white on green (0x2F) + right-arrow char (0xAF) ***
    mov word [es:di], 0x2FAF
    add di, 2
    loop draw_init_snake
    
    call Rand_Apple

Game_Loop:
    cmp byte [game_over_flag], 1
    je Go_To_Ending

    cmp byte [move_snake], 1
    jne Game_Loop

    mov byte [move_snake], 0

    cmp byte [nextDirection], 'w'
    je do_up
    cmp byte [nextDirection], 'a'
    je do_left
    cmp byte [nextDirection], 's'
    je do_down
    cmp byte [nextDirection], 'd'
    je do_right
    jmp Game_Loop

do_up:
    call move_Up
    jmp Game_Loop
do_down:
    call move_Down
    jmp Game_Loop
do_left:
    call move_Left
    jmp Game_Loop
do_right:
    call move_Right
    jmp Game_Loop

Go_To_Ending:
    call clrscr
    call Ending_Screen
    
End_Input_Loop:
    mov ah, 0
    int 16h
    
    cmp al, ' '
    je Start_New_Game
    cmp al, 27
    je Exit_Program
    
    jmp End_Input_Loop

Exit_Program:
    call restore_keyboard
    call unhook_timer
    mov ax, 0x4C00
    int 0x21

; ================= LOGIC SUBROUTINES =================

Init_Game_State:
    mov word [score], 0
    mov word [size], 5
    mov byte [Tail_Row], 12
    mov byte [Tail_Col], 37
    mov byte [Head_Row], 12
    mov byte [Head_Col], 41
    mov byte [nextDirection], 'd'
    mov byte [game_over_flag], 0
    mov byte [move_snake], 0
    mov word [tick_count], 0
    
    mov ah, 2Ch
    int 21h
    xor ax, ax
    mov al, dl
    mov ah, dh
    mov [seed], ax
    ret

Draw_Game_UI:
    push word scorestr
    push word 0
    push word 0
    call printstring
    call update_score_display
    push word line
    push word 1
    push word 0
    call printstring
    ret

; --- MOVEMENT FUNCTIONS ---

move_Right:
    push ax
    push bx
    push dx
    push si
    push di
    push es
    
    cmp byte [Head_Col], 79
    jae .set_die_right

    mov ax,0xb800
    mov es,ax
    xor ax,ax
    mov al,[Head_Row]
    mov bl,80
    mul bl
    xor bx,bx
    mov bl,[Head_Col]
    add ax,bx
    shl ax,1
    mov di,ax
    
    ; *** CHANGED: Apple is now 0x4C02 (bright red + circle char) ***
    cmp word [es:di+2],0x4C02
    je .eat_apple
    cmp word [es:di+2],0x0720
    je .move_head
    
    mov ax,[es:di+2]
    and ah,0xF0
    cmp ah,0x20          ; *** CHANGED: snake attr is now 0x2F, high nibble = 0x20 ***
    je .set_die_right
    
.set_die_right:
    mov byte [game_over_flag], 1
    jmp .end_right

.move_head:
    ; *** CHANGED: 0x2FAF = bright white on green + right-arrow (►) ***
    mov word [es:di], 0x2FAF
    mov word [es:di+2],0x2FAF
    inc byte [Head_Col]
    call Move_Tail
    jmp .end_right

.eat_apple:
    mov word [es:di], 0x2FAF
    mov word [es:di+2],0x2FAF
    inc byte [Head_Col]
    inc word [score]
    call update_score_display
    add word [size],1
    call Rand_Apple
    jmp .end_right

.end_right:
    pop es
    pop di
    pop si
    pop dx
    pop bx
    pop ax
    ret

move_Left:
    push ax
    push bx
    push dx
    push si
    push di
    push es

    cmp byte [Head_Col], 0
    jbe .set_die_left

    mov ax,0xb800
    mov es,ax
    xor ax,ax
    mov al,[Head_Row]
    mov bl,80
    mul bl
    xor bx,bx
    mov bl,[Head_Col]
    add ax,bx
    shl ax,1
    mov di,ax
    
    cmp word [es:di-2],0x4C02
    je .eat_apple_left
    cmp word [es:di-2],0x0720
    je .move_head_left
    
    mov ax,[es:di-2]
    and ah,0xF0
    cmp ah,0x20
    je .set_die_left
    
.set_die_left:
    mov byte [game_over_flag], 1
    jmp .end_left

.move_head_left:
    ; *** CHANGED: 0x2FAE = bright white on green + left-arrow (◄) ***
    mov word [es:di], 0x2FAE
    mov word [es:di-2],0x2FAE
    dec byte [Head_Col]
    call Move_Tail
    jmp .end_left

.eat_apple_left:
    mov word [es:di], 0x2FAE
    mov word [es:di-2],0x2FAE
    dec byte [Head_Col]
    inc word [score]
    call update_score_display
    add word [size],1
    call Rand_Apple
    jmp .end_left

.end_left:
    pop es
    pop di
    pop si
    pop dx
    pop bx
    pop ax
    ret

move_Up:
    push ax
    push bx
    push dx
    push si
    push di
    push es

    cmp byte [Head_Row], 2
    jbe .set_die_up

    mov ax,0xb800
    mov es,ax
    xor ax,ax
    mov al,[Head_Row]
    mov bl,80
    mul bl
    xor bx,bx
    mov bl,[Head_Col]
    add ax,bx
    shl ax,1
    mov di,ax
    
    cmp word [es:di-160],0x4C02
    je .eat_apple_up
    cmp word [es:di-160],0x0720
    je .move_head_up
    
    mov ax,[es:di-160]
    and ah,0xF0
    cmp ah,0x20
    je .set_die_up
    
.set_die_up:
    mov byte [game_over_flag], 1
    jmp .end_up

.move_head_up:
    ; *** CHANGED: 0x2F18 = bright white on green + up-arrow (▲) ***
    mov word [es:di], 0x2F18
    mov word [es:di-160],0x2F18
    dec byte [Head_Row]
    call Move_Tail
    jmp .end_up

.eat_apple_up:
    mov word [es:di], 0x2F18
    mov word [es:di-160],0x2F18
    dec byte [Head_Row]
    inc word [score]
    call update_score_display
    add word [size],1
    call Rand_Apple
    jmp .end_up

.end_up:
    pop es
    pop di
    pop si
    pop dx
    pop bx
    pop ax
    ret

move_Down:
    push ax
    push bx
    push dx
    push si
    push di
    push es

    cmp byte [Head_Row], 24
    jae .set_die_down

    mov ax,0xb800
    mov es,ax
    xor ax,ax
    mov al,[Head_Row]
    mov bl,80
    mul bl
    xor bx,bx
    mov bl,[Head_Col]
    add ax,bx
    shl ax,1
    mov di,ax
    
    cmp word [es:di+160],0x4C02
    je .eat_apple_down
    cmp word [es:di+160],0x0720
    je .move_head_down
    
    mov ax,[es:di+160]
    and ah,0xF0
    cmp ah,0x20
    je .set_die_down
    
.set_die_down:
    mov byte [game_over_flag], 1
    jmp .end_down

.move_head_down:
    ; *** CHANGED: 0x2F19 = bright white on green + down-arrow (▼) ***
    mov word [es:di], 0x2F19
    mov word [es:di+160],0x2F19
    inc byte [Head_Row]
    call Move_Tail
    jmp .end_down

.eat_apple_down:
    mov word [es:di], 0x2F19
    mov word [es:di+160],0x2F19
    inc byte [Head_Row]
    inc word [score]
    call update_score_display
    add word [size],1
    call Rand_Apple
    jmp .end_down

.end_down:
    pop es
    pop di
    pop si
    pop dx
    pop bx
    pop ax
    ret

; Move_Tail: reads direction from video memory and advances tail
Move_Tail:
    xor ax,ax
    xor bl,bl
    mov al,[Tail_Row]
    mov bl,80
    mul bl
    xor bx,bx
    mov bl,[Tail_Col]
    add ax,bx
    shl ax,1
    mov si,ax
    
    ; *** CHANGED: Match new snake word values ***
    cmp word [es:si],0x2FAF ; Right (►)
    je .tail_right
    cmp word [es:si],0x2F18 ; Up (▲)
    je .tail_up
    cmp word [es:si],0x2F19 ; Down (▼)
    je .tail_down
    cmp word [es:si],0x2FAE ; Left (◄)
    je .tail_left
    jmp .clear_tail

.tail_right:
    inc byte [Tail_Col]
    jmp .clear_tail
.tail_up:
    dec byte [Tail_Row]
    jmp .clear_tail
.tail_down:
    inc byte [Tail_Row]
    jmp .clear_tail
.tail_left:
    dec byte [Tail_Col]
    jmp .clear_tail
    
.clear_tail:
    mov word [es:si],0x0720
    ret

; ================= UTILITIES & ISRs =================

Rand_Apple:
.randagain:
    push ax
    push dx
    push di
    push es
    
    push word 22
    push word r_row
    call get_random
    add byte [r_row], 2
    
    push word 78
    push word r_col
    call get_random
    
    mov ax,80
    mov dl,[r_row]
    mul dl
    add ax,0
    mov dl, [r_col]
    xor dh, dh
    add ax, dx
    shl ax,1
    mov di,ax
    
    mov ax,0xb800
    mov es,ax
    cmp word [es:di],0x0720 
    jne .randagain_pop
    
    ; *** CHANGED: Apple = 0x4C02 = bright red bg + red fg (0x4C) + smiley/circle char (0x02) ***
    mov word [es:di], 0x4C02

    pop es
    pop di
    pop dx
    pop ax
    ret
.randagain_pop:
    pop es
    pop di
    pop dx
    pop ax
    jmp .randagain

get_random:
    push bp
    mov bp,sp
    push ax
    push bx
    push cx
    push dx
    mov ax,[seed]
    mov cx,25173
    mul cx
    add ax,13849
    mov [seed],ax
    xor dx,dx
    mov cx,[bp+6]
    div cx
    mov bx,[bp+4]
    mov [bx],dl
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 4

update_score_display:
    push ax
    push bx
    push cx
    push dx
    push es
    push di

    mov ax, 0xb800
    mov es, ax
    mov di, 14

    mov ax, [score]
    mov bx, 10
    mov cx, 0

.get_digits:
    xor dx, dx
    div bx
    push dx
    inc cx
    cmp ax, 0
    jne .get_digits

.print_digits:
    pop dx
    add dl, 0x30
    mov dh, 0x07
    mov [es:di], dx
    add di, 2
    loop .print_digits

    pop di
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    ret

printstring:
    push bp
    mov bp, sp
    push dx
    push ax
    push si
    push di
    push es
    
    mov ax, 0xb800
    mov es, ax
    mov si, [bp + 8]
    mov ax, [bp + 6] 
    mov dl, 80
    mul dl
    add ax, [bp + 4]
    shl ax, 1
    mov di, ax
    mov ah, 0x0A

.ploop:
    lodsb
    cmp al, 0
    je .pend
    stosw
    call delay
    jmp .ploop

.pend:
    pop es
    pop di
    pop si
    pop ax
    pop dx
    pop bp
    ret 6

printnum:
    push bp
    mov bp, sp
    push es
    push ax
    push bx
    push cx
    push dx
    push di

    mov ax, 0xb800
    mov es, ax
    mov ax, [bp+6] 
    mov bl, 80
    mul bl
    add ax, [bp+4] 
    shl ax, 1
    mov di, ax
    mov ax, [bp+8]
    mov bx, 10
    mov cx, 0

.pnext:
    mov dx, 0
    div bx
    add dl, 0x30
    push dx
    inc cx
    cmp ax, 0
    jnz .pnext

.ppos:
    pop dx
    mov dh, 0x07
    mov [es:di], dx
    add di, 2
    loop .ppos

    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    pop es
    pop bp
    ret 6

clrscr:
    push es
    push di
    push cx
    push ax
    
    mov ax, 0xb800
    mov es, ax
    mov cx, 2000
    mov ax, 0x0720
    xor di, di
    rep stosw
    
    pop ax
    pop cx
    pop di
    pop es
    ret

; --- SCREENS ---
Starting_Screen:
    push word main_1
    push word 3
    push word 17
    call printstring
    push word main_2
    push word 4
    push word 17
    call printstring
    push word main_3
    push word 5
    push word 17
    call printstring
    push word main_4
    push word 6
    push word 17
    call printstring
    push word main_5
    push word 7
    push word 17
    call printstring
    push word main_6
    push word 8
    push word 17
    call printstring
    push word main_7
    push word 9
    push word 17
    call printstring
    push word main_8
    push word 10
    push word 17
    call printstring
    push word main_9
    push word 11
    push word 17
    call printstring
    push word main_10
    push word 12
    push word 17
    call printstring
    push word main_11
    push word 13
    push word 17
    call printstring
    push word main_12
    push word 14
    push word 17
    call printstring
    push word main_13
    push word 15
    push word 17
    call printstring
    push word main_14
    push word 16
    push word 17
    call printstring
    push word main_15
    push word 17
    push word 17
    call printstring
    push word main_16
    push word 18
    push word 10
    call printstring
    push word main_17
    push word 19
    push word 10
    call printstring
    push word main_18
    push word 20
    push word 10
    call printstring
    push word main_19
    push word 21
    push word 10
    call printstring
    push word main_20
    push word 22
    push word 10
    call printstring
    ret

Ending_Screen:
    push word main_21
    push word 2
    push word 10
    call printstring
    push word main_22
    push word 3
    push word 10
    call printstring
    push word main_23
    push word 4
    push word 10
    call printstring
    push word main_24
    push word 5
    push word 10
    call printstring
    push word main_25
    push word 6
    push word 10
    call printstring
    push word main_26
    push word 7
    push word 10
    call printstring

    push word box_top
    push word 10
    push word 28
    call printstring
    push word box_mid
    push word 11
    push word 28
    call printstring
    push word box_bot
    push word 12
    push word 28
    call printstring

    push word [score]
    push word 11
    push word 42
    call printnum

    push word btn1_top
    push word 15
    push word 15
    call printstring
    push word btn1_mid
    push word 16
    push word 15
    call printstring
    push word btn1_txt
    push word 17
    push word 15
    call printstring
    push word btn1_bot
    push word 18
    push word 15
    call printstring

    push word btn2_top
    push word 15
    push word 45
    call printstring
    push word btn2_mid
    push word 16
    push word 45
    call printstring
    push word btn2_txt
    push word 17
    push word 45
    call printstring
    push word btn2_bot
    push word 18
    push word 45
    call printstring
    ret

; ================= INTERRUPT HANDLERS =================

INT9_Handler:
    push ax
    in al, 0x60
    test al, 0x80
    jnz .pass_to_bios

    cmp al, 0x11
    je .handle_W
    cmp al, 0x1E
    je .handle_A
    cmp al, 0x1F
    je .handle_S
    cmp al, 0x20
    je .handle_D
    jmp .pass_to_bios

.handle_W:
    cmp byte [cs:nextDirection], 's'
    je .consume_key
    mov byte [cs:nextDirection],'w'
    jmp .consume_key

.handle_A:
    cmp byte [cs:nextDirection], 'd'
    je .consume_key
    mov byte [cs:nextDirection],'a'
    jmp .consume_key

.handle_S:
    cmp byte [cs:nextDirection], 'w'
    je .consume_key
    mov byte [cs:nextDirection],'s'
    jmp .consume_key

.handle_D:
    cmp byte [cs:nextDirection], 'a'
    je .consume_key
    mov byte [cs:nextDirection],'d'
    jmp .consume_key

.consume_key:
    in al,0x61
    mov ah,al
    or al,0x80
    out 0x61,al
    mov al,ah
    out 0x61,al
    mov al,0x20
    out 0x20,al
    pop ax
    iret

.pass_to_bios:
    pop ax
    jmp far [cs:old_isr_kb]

hook_keyboard:
    mov ah, 0x35
    mov al, 0x09
    int 0x21
    mov [old_isr_kb], bx
    mov [old_isr_kb+2], es
    mov ah, 0x25
    mov al, 0x09
    mov dx, INT9_Handler
    int 0x21
    ret

restore_keyboard:
    lds dx, [old_isr_kb]
    mov ah, 0x25
    mov al, 0x09
    int 0x21
    ret
    
INT8_Handler:
    push ax
    inc  word [cs:tick_count]
    cmp  word [cs:tick_count], 2
    jl   .chain_to_bios
    mov  word [cs:tick_count],0
    mov  byte [cs:move_snake],1
.chain_to_bios:
    pop  ax
    jmp  far [cs:old_isr_tm]

hook_timer:
    push ax
    push bx
    push dx
    push es

    mov ah,0x35
    mov al,0x08
    int 0x21
    mov [old_isr_tm],bx
    mov [old_isr_tm+2],es

    mov word [tick_count],0
    mov byte [move_snake],0

    mov ah,0x25
    mov al,0x08
    mov dx, INT8_Handler
    int 0x21

    pop es
    pop dx
    pop bx
    pop ax
    ret

unhook_timer: 
    push ax
    push dx
    push ds
    mov ah,0x25
    mov al,0x08
    lds dx,[old_isr_tm]
    int 0x21
    pop ds
    pop dx
    pop ax
    ret
    
delay:
    push cx
    push dx
    mov cx, 0x0001
delay_outer:
    mov dx, 0x0f00
delay_inner:
    dec dx
    jnz delay_inner
    loop delay_outer
    pop dx
    pop cx
    ret