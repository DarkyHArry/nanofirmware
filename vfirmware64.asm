section .data
    ;  Print the welcome to new users
    msg_welcome db "---------> Virtual Machine x86_64 on Linux <----------", 0xA, 
            db "Set the bytes (max 16 bytes).", 0xA,
            db "Supported formats (decimal): ", 0xA,
            db " 1 [Reg]  [Val]  -> MOV (Reg: 0=Ax, 1=BX, 2=CX)", 0xA,
                db " 2 [RegD] [Reg0] -> ADD (add Reg0 in RegD)", 0xA,
            db " 3       -> SYS_PRINT (show the registers)", 0xA,
                db " 0       -> HALT (close the VM)", 0xA, 0xA,
            db "How many bytes does your program have: ", 0

    msg_prompt db "Set the byte %d: ", 0
    fmt_input  db "%d", 0
    
    msg_exec   db 10, "--- Starting Execution ---", 0xA, 0
    msg_status db " --- Current Status Of Registers ---", 0xA, 0
    fmt_reg    db "V_AX: %ld | V_BX: %ld | V_CX: %ld", 0xA, 0
    msg_exit   db 10, "[Sucessfully] Real Hardware is protected. VM Off.", 0xA, 0


section .bss
    ; buffer to users
    virtual_code resb 16
    num_byte    resq 1
    temp_byte     resq 1

    ; virtual protected registers
    v_ax resq 1
    v_bx resq 1
    v_cx resq 1
    
section .text
    global main
    extern printf
    extern scanf

main:
    push rbp
    mov rbp, rsp

    ; clear the virtual protected registers
    mov qword [v_ax], 0
    mov qword [v_bx], 0
    mov qword [v_cx], 0
    
    ; write the message "welcome"
    mov rdi, msg_welcome
    xor rax, rax
    call printf

    ; ask the user what the program size is
    mov rdi, fmt_input
    mov rsi, num_byte
    xor rax, rax
    call scanf

    ; if 0 or less, exit
    cmp qword [num_byte], 0
    jle .exit_system
    cmp qword [num_byte], 16 ; max buffer 16
    jg .exit_system

    xor r12, r12

    ; loop to read the user program
.input_loop:
    cmp r12, [num_byte]
    jge .start_vm

    ; user promto to know what the byte is typing
    mov rdi, msg_prompt
    mov rsi, r12
    xor rax, rax
    call printf
    
    ; read the byte
    mov rdi, fmt_input
    mov rsi, temp_byte
    xor rax, rax
    call scanf

    ; move the byte to buffer after read ( virtual code ).
    mov rax, [temp_byte]
    mov [virtual_code + r12], al
    
    inc r12
    jmp .input_loop

    ; firmware
.start_vm:
    mov rdi, msg_exec
    xor rax, rax
    call printf

    ; virtual RSI to initial buffer
    mov rsi, virtual_code

.fetch_decode_loop:
    ; FETCH
    movzx rax, byte [rsi]
    inc rsi

    ; DECODE and EXECUTE
    cmp al, 0x00        ;  0 = HALT
    je .exit_system

    cmp al, 0x01        ;  1 = MOV
    je .vm_mov
    
    cmp al, 0x02        ; 2 = ADD
    je .vm_add

    cmp al, 0x03
    je .vm_print

    jmp .fetch_decode_loop

    ; virtual logic instructions
.vm_mov:
    movzx rbx, byte [rsi]   ; destiny (0, 1 or 2)
    inc rsi
    movzx rcx, byte [rsi]   ; immediate value
    inc rsi

    cmp rbx, 0
    je .set_ax
    cmp rbx, 1
    je .set_bx
    mov [v_cx], rcx
    jmp .fetch_decode_loop

.set_ax:
    mov [v_ax], rcx
    jmp .fetch_decode_loop

.set_bx:
    mov [v_bx], rcx
    jmp .fetch_decode_loop
    
.vm_add:
    movzx rbx, byte [rsi]   ; destiny
    inc rsi
    movzx rcx, byte [rsi]   ; origem
    inc rsi

    mov rdx, 0
    cmp rcx, 0
    je .get_ax
    cmp rcx, 1
    je .get_bx
    mov rdx, [v_cx]
    jmp .apply_add

.get_ax:
    mov rdx, [v_ax]
    jmp .apply_add

.get_bx:
    mov rdx, [v_bx]

.apply_add:
    cmp rbx, 0
    je .add_to_ax
    cmp rbx, 1
    je .add_to_bx
    add [v_cx], rdx
    jmp .fetch_decode_loop

.add_to_ax:
    add [v_ax], rdx
    jmp .fetch_decode_loop

.add_to_bx:
    add [v_bx], rdx
    jmp .fetch_decode_loop

.vm_print:
    ; save the actual pointer the VM on the real stack.
    push rsi

    mov rdi, msg_status
    xor rax, rax
    call printf
    
    mov rdi, fmt_reg
    mov rsi, [v_ax]
    mov rdx, [v_bx]
    mov rcx, [v_cx]
    xor rax, rax
    call printf

    pop rsi     ; restore the pointer on VM
    jmp .fetch_decode_loop

.exit_system:
    mov rdi, msg_exit
    xor rax, rax
    call printf

    mov rsp, rbp
    pop rbp
    mov rax, 0
    ret
