# VCPU: A Tiny Virtual Machine in Assembly

Welcome to the **VCPU** (Virtual CPU) project! This program is a simple, low-level emulator written in x86_64 assembly. It essentially creates a "mini-computer" inside your computer to demonstrate how a real processor fetches, decodes, and executes instructions.

## The Big Idea

The core concept here is **hardware abstraction**. Instead of running code directly on your physical processor, this program sets up a safe, "virtual" environment. 

1.  **Safety**: It protects your real hardware. If you write a "buggy" program for this VM, it only affects the virtual registers, not your actual system state.
2.  **Education**: It shows the fundamental "Fetch-Decode-Execute" cycle that every CPU uses.
3.  **Simplicity**: It uses a very small set of instructions and only three "registers" (storage slots), making it easy to see exactly what is happening under the hood.

---

## Example Walkthrough

Here is a look at the VCPU in action:

![VCPU Demo](https://private-us-east-1.manuscdn.com/sessionFile/4M73KZDSdfRY0Zu25R8gV0/sandbox/bGRDdDj0WbDbDGr2qnsNaG-images_1780103007618_na1fn_L2hvbWUvdWJ1bnR1L3ZjcHVfZGVtbw.png?Policy=eyJTdGF0ZW1lbnQiOlt7IlJlc291cmNlIjoiaHR0cHM6Ly9wcml2YXRlLXVzLWVhc3QtMS5tYW51c2Nkbi5jb20vc2Vzc2lvbkZpbGUvNE03M0taRFNkZlJZMFp1MjVSOGdWMC9zYW5kYm94L2JHUkRkRGowV2JEYkRHcjJxbnNOYUctaW1hZ2VzXzE3ODAxMDMwMDc2MThfbmExZm5fTDJodmJXVXZkV0oxYm5SMUwzWmpjSFZmWkdWdGJ3LnBuZyIsIkNvbmRpdGlvbiI6eyJEYXRlTGVzc1RoYW4iOnsiQVdTOkVwb2NoVGltZSI6MTc5ODc2MTYwMH19fV19&Key-Pair-Id=K2HSFNDJXOU9YS&Signature=Kvhkh2Ka5UReMmeqok1YuJ6CuMbn32cSSjoM25Z4Ng-Iw6MtES0gkFHhpKElyPgJzqGPYFr1kaDl9reH~pElzFIk~bFhO~g7xBXOnryr4KALL3FaKghB2FWX2igBmSuzSSpVDJjOpBAP9OMjqAtUk6hQKzXvRTYIGX4AclGLSaYO04T43qwMIRy3hvt6yKOrv76DBHvIMehLQLSwUdCqvaqkf6dS01YW~TBHIIllzNB8vv-3~V17XmuDLMqUptHrJ2FoaXIvs-BD7-cnW6rGmaxAkp9pHNn~LuXuDc5x4BrxHzuzH412-8LLft6Yv-YUdysOmZqluYIONdLV3j0fTg__)

### Breaking Down the Screenshot
In the example above, a 10-byte program was entered. Let's decode what happened:

1.  **`1, 0, 50`**: (Bytes 0-2) Move the value **50** into Register **0** (V_AX).
2.  **`1, 1, 50`**: (Bytes 3-5) Move the value **50** into Register **1** (V_BX).
3.  **`2, 0, 1`**: (Bytes 6-8) Add the value of Register **1** into Register **0**. 
    *   *Result*: V_AX (50) + V_BX (50) = **100**.
4.  **`3`**: (Byte 9) Print the status.
    *   As you can see in the output: `V_AX: 100 | V_BX: 50 | V_CX: 0`.

---

## How the Program Works

The program follows a clear three-step process:

### 1. Setup & Input
First, the program clears its virtual registers (`V_AX`, `V_BX`, `V_CX`) to zero. It then asks you how many bytes your "program" will have (up to 16 bytes). You then type in the numbers (the machine code) one by one. These numbers are stored in a small memory buffer called `virtual_code`.

### 2. The Fetch-Decode-Execute Loop
Once your code is loaded, the VM starts. It uses a pointer (the `rsi` register in the real CPU) to keep track of which byte it is currently reading.
*   **Fetch**: It grabs the next byte from memory.
*   **Decode**: It looks at the number to see what it means (e.g., "Is this a MOV or an ADD?").
*   **Execute**: It performs the actual math or data movement.

### 3. Exit
The VM keeps running until it hits a `HALT` instruction or finishes your bytes, then it safely shuts down.

---

## The Instruction Set (The "Language")

The VCPU understands four basic commands. Think of these as the "verbs" of your virtual language:

| Opcode (Number) | Name | What it does | Example |
| :--- | :--- | :--- | :--- |
| **0** | **HALT** | Stops the VM immediately. | `0` |
| **1** | **MOV** | Puts a specific number into a register. It needs two more bytes: the register ID and the value. | `1, 0, 50` (Move 50 into AX) |
| **2** | **ADD** | Adds the value of one register into another. It needs two more bytes: the target register and the source register. | `2, 1, 0` (Add AX to BX) |
| **3** | **PRINT** | Shows the current values of all three virtual registers on your screen. | `3` |

### Register IDs
When using MOV or ADD, you refer to the registers by these numbers:
*   **0**: `V_AX` (Virtual Accumulator)
*   **1**: `V_BX` (Virtual Base)
*   **2**: `V_CX` (Virtual Counter)

---

## Detailed Instruction Breakdown

### `MOV [Register] [Value]` (Opcode 1)
When the VM sees a `1`, it knows the next two bytes are important. 
- It reads the first byte to pick the destination (0, 1, or 2).
- It reads the second byte to get the actual number you want to store.

### `ADD [Target] [Source]` (Opcode 2)
When the VM sees a `2`, it prepares to do math.
- It looks at the "Source" register to see what value is inside.
- It then adds that value to whatever is already in the "Target" register.

### `SYS_PRINT` (Opcode 3)
This is a "System Call." It pauses the execution logic to talk to your real operating system and print the state of the registers to the terminal.

### `HALT` (Opcode 0)
The most important command! Without this, the VM might keep trying to read empty memory. It tells the program: "We are done, clean up and exit."
