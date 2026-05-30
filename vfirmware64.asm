section .data
    ; -------------------------------------------------------------------------
    ; SEÇÃO DE DADOS (.data)
    ; Aqui definimos as mensagens de texto que serão exibidas na tela.
    ; O '0xA' representa uma quebra de linha (Enter).
    ; O '0' no final de cada string indica o fim do texto (padrão da linguagem C).
    ; -------------------------------------------------------------------------
    
    ; Mensagem de boas-vindas e instruções de uso
    msg_welcome db "---------> Virtual Machine x86_64 on Linux <----------", 0xA, 
            db "Defina os bytes (maximo de 16 bytes).", 0xA,
            db "Formatos suportados (em decimal): ", 0xA,
            db " 1 [Reg]  [Val]  -> MOV (Reg: 0=Ax, 1=BX, 2=CX)", 0xA,
            db " 2 [RegD] [Reg0] -> ADD (adiciona Reg0 dentro de RegD)", 0xA,
            db " 3       -> SYS_PRINT (mostra o valor dos registradores)", 0xA,
            db " 0       -> HALT (desliga a Maquina Virtual)", 0xA, 0xA,
            db "Quantos bytes o seu programa tem: ", 0

    ; Mensagem para pedir cada byte individualmente
    msg_prompt db "Defina o byte %d: ", 0
    
    ; Formato para ler números inteiros (usado pelo scanf)
    fmt_input  db "%d", 0
    
    ; Mensagens de status do sistema
    msg_exec   db 10, "--- Iniciando a Execucao ---", 0xA, 0
    msg_status db " --- Status Atual dos Registradores ---", 0xA, 0
    
    ; Formato para imprimir o valor dos 3 registradores virtuais
    fmt_reg    db "V_AX: %ld | V_BX: %ld | V_CX: %ld", 0xA, 0
    
    ; Mensagem de encerramento
    msg_exit   db 10, "[Sucesso] O Hardware Real esta protegido. VM Desligada.", 0xA, 0


section .bss
    ; -------------------------------------------------------------------------
    ; SEÇÃO DE VARIÁVEIS NÃO INICIALIZADAS (.bss)
    ; Aqui reservamos espaço na memória para guardar dados que vão mudar.
    ; -------------------------------------------------------------------------
    
    ; Buffer (espaço de memória) para guardar o código digitado pelo usuário
    ; 'resb 16' reserva 16 bytes. É aqui que o programa virtual vai morar.
    virtual_code resb 16
    
    ; Variáveis para guardar a quantidade de bytes e o byte temporário lido
    ; 'resq 1' reserva 1 quadword (8 bytes), tamanho padrão para números em 64 bits.
    num_byte    resq 1
    temp_byte   resq 1

    ; Nossos Registradores Virtuais Protegidos!
    ; Em vez de usar os registradores reais da CPU, criamos "variáveis" para simular eles.
    v_ax resq 1  ; Registrador 0
    v_bx resq 1  ; Registrador 1
    v_cx resq 1  ; Registrador 2
    
section .text
    ; -------------------------------------------------------------------------
    ; SEÇÃO DE CÓDIGO (.text)
    ; Aqui fica a lógica real do programa em Assembly x86_64.
    ; -------------------------------------------------------------------------
    global main
    extern printf  ; Importa a função printf do C (para escrever na tela)
    extern scanf   ; Importa a função scanf do C (para ler do teclado)

main:
    ; Prepara a pilha (padrão de funções em C/Assembly)
    push rbp
    mov rbp, rsp

    ; -------------------------------------------------------------------------
    ; PASSO 1: INICIALIZAÇÃO
    ; -------------------------------------------------------------------------
    ; Limpa os registradores virtuais, garantindo que comecem com valor zero.
    mov qword [v_ax], 0
    mov qword [v_bx], 0
    mov qword [v_cx], 0
    
    ; Imprime a mensagem de boas-vindas
    ; rdi recebe o texto, rax é zerado (exigência do printf), e chamamos a função.
    mov rdi, msg_welcome
    xor rax, rax
    call printf

    ; Pergunta ao usuário qual o tamanho do programa
    ; rdi recebe o formato ("%d"), rsi recebe o endereço onde salvar (num_byte)
    mov rdi, fmt_input
    mov rsi, num_byte
    xor rax, rax
    call scanf

    ; Verifica se o tamanho digitado é válido
    cmp qword [num_byte], 0
    jle .exit_system         ; Se for menor ou igual a 0, sai do programa
    cmp qword [num_byte], 16 
    jg .exit_system          ; Se for maior que 16 (limite do buffer), sai do programa

    ; Zera o registrador r12. Ele será nosso "contador" no loop de leitura.
    xor r12, r12

    ; -------------------------------------------------------------------------
    ; PASSO 2: LER O PROGRAMA DO USUÁRIO
    ; -------------------------------------------------------------------------
.input_loop:
    ; Compara o contador (r12) com a quantidade de bytes que o usuário quer digitar
    cmp r12, [num_byte]
    jge .start_vm  ; Se já leu tudo (r12 >= num_byte), pula para iniciar a VM

    ; Mostra na tela: "Defina o byte X: "
    mov rdi, msg_prompt
    mov rsi, r12
    xor rax, rax
    call printf
    
    ; Lê o número digitado e salva na variável temporária 'temp_byte'
    mov rdi, fmt_input
    mov rsi, temp_byte
    xor rax, rax
    call scanf

    ; Move o byte lido para dentro do nosso buffer 'virtual_code'
    ; Exemplo: Se r12 for 0, salva na posição 0. Se for 1, salva na posição 1.
    mov rax, [temp_byte]
    mov [virtual_code + r12], al  ; 'al' pega apenas 1 byte (a parte mais baixa de rax)
    
    inc r12          ; Aumenta o contador (r12 = r12 + 1)
    jmp .input_loop  ; Volta para o início do loop para ler o próximo byte

    ; -------------------------------------------------------------------------
    ; PASSO 3: O "FIRMWARE" DA MÁQUINA VIRTUAL
    ; -------------------------------------------------------------------------
.start_vm:
    ; Avisa que a execução vai começar
    mov rdi, msg_exec
    xor rax, rax
    call printf

    ; Configura o registrador RSI para apontar para o início do nosso código virtual
    ; RSI será o nosso "Instruction Pointer" (Ponteiro de Instrução) virtual.
    mov rsi, virtual_code

    ; -------------------------------------------------------------------------
    ; O CICLO FETCH-DECODE-EXECUTE (Busca-Decodifica-Executa)
    ; É assim que todo processador do mundo funciona!
    ; -------------------------------------------------------------------------
.fetch_decode_loop:
    ; FETCH (BUSCA): Pega o próximo byte da memória apontada por RSI
    movzx rax, byte [rsi]
    inc rsi  ; Avança o ponteiro para o próximo byte

    ; DECODE (DECODIFICA): Descobre qual comando o usuário digitou
    cmp al, 0x00        ; O comando é 0? (HALT)
    je .exit_system     ; Se sim, pula para desligar o sistema

    cmp al, 0x01        ; O comando é 1? (MOV)
    je .vm_mov          ; Se sim, pula para a lógica do MOV
    
    cmp al, 0x02        ; O comando é 2? (ADD)
    je .vm_add          ; Se sim, pula para a lógica do ADD

    cmp al, 0x03        ; O comando é 3? (PRINT)
    je .vm_print        ; Se sim, pula para a lógica de imprimir

    ; Se não for nenhum comando conhecido, ignora e busca o próximo
    jmp .fetch_decode_loop

    ; -------------------------------------------------------------------------
    ; LÓGICA DAS INSTRUÇÕES VIRTUAIS (EXECUTE)
    ; -------------------------------------------------------------------------

.vm_mov:
    ; EXEMPLO DE USO: 1, 0, 50 (Move o valor 50 para o registrador 0)
    
    ; Lê o próximo byte: Qual é o registrador de destino? (0, 1 ou 2)
    movzx rbx, byte [rsi]   
    inc rsi
    
    ; Lê o próximo byte: Qual é o valor que vamos guardar?
    movzx rcx, byte [rsi]   
    inc rsi

    ; Verifica qual registrador foi escolhido e pula para salvar nele
    cmp rbx, 0
    je .set_ax
    cmp rbx, 1
    je .set_bx
    
    ; Se não for 0 nem 1, assume que é 2 (v_cx) e salva direto
    mov [v_cx], rcx
    jmp .fetch_decode_loop  ; Volta para buscar a próxima instrução

.set_ax:
    mov [v_ax], rcx         ; Salva o valor em v_ax
    jmp .fetch_decode_loop

.set_bx:
    mov [v_bx], rcx         ; Salva o valor em v_bx
    jmp .fetch_decode_loop
    
.vm_add:
    ; EXEMPLO DE USO: 2, 0, 1 (Adiciona o valor do reg 1 dentro do reg 0)
    
    ; Lê o próximo byte: Qual é o registrador de destino (que vai receber a soma)?
    movzx rbx, byte [rsi]   
    inc rsi
    
    ; Lê o próximo byte: Qual é o registrador de origem (que tem o valor a ser somado)?
    movzx rcx, byte [rsi]   
    inc rsi

    ; Primeiro, vamos descobrir qual é o valor da origem e guardar em RDX
    mov rdx, 0
    cmp rcx, 0
    je .get_ax
    cmp rcx, 1
    je .get_bx
    mov rdx, [v_cx]  ; Se for 2, pega o valor de v_cx
    jmp .apply_add

.get_ax:
    mov rdx, [v_ax]  ; Pega o valor de v_ax
    jmp .apply_add

.get_bx:
    mov rdx, [v_bx]  ; Pega o valor de v_bx

.apply_add:
    ; Agora que temos o valor em RDX, vamos somar no destino correto
    cmp rbx, 0
    je .add_to_ax
    cmp rbx, 1
    je .add_to_bx
    
    ; Se for 2, soma em v_cx
    add [v_cx], rdx
    jmp .fetch_decode_loop

.add_to_ax:
    add [v_ax], rdx  ; Soma o valor em v_ax
    jmp .fetch_decode_loop

.add_to_bx:
    add [v_bx], rdx  ; Soma o valor em v_bx
    jmp .fetch_decode_loop

.vm_print:
    ; EXEMPLO DE USO: 3 (Apenas imprime o status atual)
    
    ; Salva o nosso ponteiro virtual (RSI) na pilha real.
    ; Fazemos isso porque a função printf vai alterar o RSI, e não queremos perder onde estávamos no código!
    push rsi

    ; Imprime o cabeçalho de status
    mov rdi, msg_status
    xor rax, rax
    call printf
    
    ; Prepara os valores para imprimir: V_AX, V_BX e V_CX
    mov rdi, fmt_reg
    mov rsi, [v_ax]
    mov rdx, [v_bx]
    mov rcx, [v_cx]
    xor rax, rax
    call printf

    ; Restaura o nosso ponteiro virtual da pilha
    pop rsi     
    jmp .fetch_decode_loop  ; Volta para buscar a próxima instrução

    ; -------------------------------------------------------------------------
    ; PASSO 4: DESLIGAR O SISTEMA
    ; -------------------------------------------------------------------------
.exit_system:
    ; Imprime a mensagem de saída
    mov rdi, msg_exit
    xor rax, rax
    call printf

    ; Restaura a pilha e finaliza o programa (padrão C/Assembly)
    mov rsp, rbp
    pop rbp
    mov rax, 0  ; Retorna 0 (Sucesso)
    ret
