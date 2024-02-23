.file stddef.asm

.section .data
_strtok_cur_ptr: .word 0

.section .text
.globl bzero
.globl memchr
.globl memcmp
.globl memcpy
.globl memmove
.globl memset
.globl strcat
.globl strncat
.globl strchr
.globl strcmp
.globl strncmp
.globl strcoll
.globl strcpy
.globl strncpy
.globl strcspn
.globl strerror
.globl strlen
.globl strpbrk
.globl strrchr
.globl strspn
.globl strstr
.globl strtok
.globl strxfrm

bzero:
	## args
	# a0 = void *s
	# a1 = size_t n
	## local
	# t1 = temporary register

	addi sp, sp, -16 # Enter stack frame
	sw ra, 0(sp)
	mv t1, a1
	li a1, 0
	mv a2, t1
	call memset
	lw ra, 0(sp)
	addi sp, sp,  16 # Leave stack frame
	ret

memchr:
	## args
	# a0 = const void *s
	# a1 = int c
	# a2 = size_t
	## local
	# t0 = temporary address
	# t1 = iterator
	## return
	# a0 = returns the address of a matching character by default, but returns 0 if no matching character is found.

	li t1, 0
1:
	bgeu t1, a2, 1f
	add t0, a0, t1
	lb t0, 0(t0)
	addi t1, t1, 1
	bnez t0, a1, 1b
	add a0, a0, t1
1:
	li a0, NULL
	ret

memcmp:
	## args
	# a0 = const void *str1
	# a1 = const void *str2
	# a2 = size_t n
	## local
	# t0 = temporary address, buffer
	# t1 = iterator
	# t2 = temporary address, buffer
	## return
	# a0 = a0 and a1 is has a same content, returns 0, a0 bigger than a1, returns a positive value, a1 bigger than a0, returns a negative value

	li t1, 0
1:
	# OPTIMIZATION
	or t0, a0, a1
	or t0, t0, a2
	andi t0, t0, 3
	beqz t0, 2f
1:
	bgeu t1, a2, 3f # If i > n, then return
	add t0, a0, t1
	lb t0, 0(t0)
	add t2, a1, t1
	lb t2, 0(t2)
	sub t0, t0, t2
	addi t1, t1, 4
	bnez t0, 1b
	j 3f
2:
	bgeu t1, a2, 3f # If i > n, then return
	add t0, a0, t1
	lw t0, 0(t0)
	add t2, a1, t1
	lw t2, 0(t2)
	sub t0, t0, t2
	addi t1, t1, 4
	bnez t0, 2b
3:
	mv a0, t0
	ret

memcpy:
	## args
	# a0 = void *dst
	# a1 = const void *src
	# a2 = size_t n
	## local
	# t0 = temporary address
	# t1 = iterator
	# t2 = byte, word buffer
	## return
	# a0 = void *

	# OPTIMIZATION
	or t0, a0, a1
	or t0, t0, a2
	andi t0, t0, 3
	li t1, 0
	beqz t0, 1f
	j 2f
1:
	bgeu t1, a2, 3f # If i > n, then return
	add t0, a1, t1
	lw t2, 0(t0)
	add t0, a0, t1
	sw t2, 0(t0)
	addi t1, t1, 4
	j 1b
2:	# loop
	bgeu t1, a2, 3f # If i > n, then return
	add t0, a1, t1
	lb t2, 0(t0)
	add t0, a0, t1
	sb t2, 0(t0)
	addi t1, t1, 1
	j 2b
3:
	ret

memmove:
	## args
	# a0 = void *dst
	# a1 = const void *src
	# a2 = size_t n
	## local
	# t0 = temporary address
	# t1 = iterator
	# t2 = byte, word buffer
	# return
	# a0 = return always a0
	bgeu a0, a1, 1f
	addi sp, sp, -16 # Enter stack frame
	sw ra, 0(sp)
	call memcpy
	# del stack frame
	lw ra, 0(sp)
	addi sp, sp,  16 # Leave stack frame
	j 3f
1:
	# OPTIMIZATION
	or t0, a0, a1
	or t0, t0, a2
	andi t0, t0, 3
	bnez t0, 2f
	beqz a2, 3f
	addi t1, a2, -4
1:
	beqz t1, 3f
	add t0, a1, t1
	lw t2, 0(t0)
	add t0, a0, t1
	sw t2, 0(t0)
	addi t1, t1, -4
	j 1b
2:
	addi t1, a2, -1
2:
	beqz t1, 3f
	add t0, a1, t1
	lb t2, 0(t0)
	add t0, a0, t1
	sb t2, 0(t0)
	addi t1, t1, -1
	j 2b
3:
	ret

memset:
	## args
	# a0 = void *s
	# a1 = int c
	# a2 = size_t n
	# local
	# t0 = temporary address
	# t1 = iterator
	# return
	# a0 = return always a0

	li t1, 0
	# OPTIMIZATION
	or t0, a0, a1
	or t0, t0, a2
	andi t0, t0, 3
	beqz t0, 2f
1:
	bgeu t1, a2, 3f
	add t0, a0, t1
	sb a1, 0(t0)
	addi t1, t1, 1
	j 1b
2:
	mv t0, a1
2:
	beqz a1, 2f # If a1 == 0, then do not duplicate bytes
	slli a1, a1, 8
	or t0, t0, a2
	j 2b
2:
	bgeu t1, a2, 3f
	add t0, a0, t1
	sw a1, 0(t0)
	addi t1, t1, 1
	j 2b
3:
	ret

strcat:
	## args
	# a0 = char *dst
	# a1 = const char *src
	## local
	# t1 = temporary value
	## return
	# a0 = always return first a0 value

	addi sp, sp, -16 # Enter stack frame
	sw ra, 0(sp)
	sw a0, 4(sp)
	sw a1, 8(sp)
	call strlen
	lw t1, 4(sp)
	add a0, t1, a0
	lw a1, 8(sp)
	call strcpy
	lw ra, 0(sp)
	addi sp, sp,  16 # Leave stack frame
	ret

strncat:
	## args
	# a0 = char *dst
	# a1 = char *src
	# a2 = size_t sz
	## local
	# t0 = temporary value 0
	# t1 = temporary value 1
	## return
	# a0 = always return first a0 value

	addi sp, sp, -16 # Enter stack frame
	sw ra, 0(sp)
	sw a0, 4(sp)
	sw a1, 8(sp)
	sw a2, 12(sp)
	mv a0, a1
	mv a1, a2
	call strnlen
	mv t0, a0
	lw t1, 4(sp)
	mv a0, t1
	call strlen
	add a0, t1, a0
	lw a1, 8(sp)
	mv a2, t0
	add t0, t0, a0
	sb zero, 0(t0)
	call memcpy
	lw ra, 0(sp)
	addi sp, sp,  16 # Leave stack frame
	ret

strchr:
	## args
	# a0 = const char *s
	# a1 = int c
	## local
	# t0 = temporary address, buffer
	# t1 = iterator
	## return
	# a0 = functions return a pointer to the matched character or NULL if the character is not found.  The terminating null byte is considered part of the string, so that if c is specified as '\0', these functions return a pointer to the terminator.

	li t1, 0
1:
	add t0, a0, t1
	lb t0, 0(t0)
	bne t0, a1, 1b
	add a0, a0, t1
	ret

strcmp:
	## args
	# a0 = const char *s1
	# a1 = const char *s2
	## return
	# a0 = return an integer greater than, equal to, or less than 0, if the object pointed to by a0 is greater than, equal to, or less than the object pointed to by a1, respectively.

	addi sp, sp, -16 # Enter stack frame
	sw ra, 0(sp)
	li a2, -1 # INT_MIN - 1
	call memcmp
	lw ra, 0(sp)
	addi sp, sp, 16  # Leave stack frame
	ret

strncmp:
	## args
	# a0 = const char *s1
	# a1 = const char *s2
	# a2 = size_t n
	## return
	# a0 = return an integer greater than, equal to, or less than 0, if the object pointed to by a0 is greater than, equal to, or less than the object pointed to by a1, respectively.

	# Enter stack frame
	addi sp, sp, -16
	sw ra, 0(sp)
	sw a0, 4(sp)
	sw a1, 8(sp)
	call strlen
	mv a2, a0
	lw a0, 4(sp)
	lw a1, 8(sp)
	call memcmp
	lw ra, 0(sp)
	addi sp, sp, 16
	ret

strcoll:
	UNIMP
	ret

strcpy:
	## args
	# a0 = char *dst
	# a1 = const char *src
	## local
	# t0 = temporary address
	## return
	# a0 = return always a0

	addi sp, sp, -16 # Enter stack frame
	sw ra, 0(sp)
	sw a0, 4(sp)
	sw a1, 8(sp)
	mv a0, a1
	call strlen
	mv a2, a0
	sb zero, 0(a0) # dst[strlen(src)] = '\0'
	lw a1, 8(sp)
	lw a0, 4(sp)
	call memcpy
	lw a0, 4(sp)
	lw ra, 0(sp)
	addi sp, sp, 16  # Leave stack frame
	ret

strncpy:
	## args
	# a0 = char *dst
	# a1 = const char *src
	# a2 = unsigned int n
	## return
	# a0 = return always a0

	addi sp, sp, -16 # Enter stack frame
	sw ra, 0(sp)
	sw a0, 4(sp)
	sw a1, 8(sp)
	sw a2, 12(sp)
	mv a1, a2
	call bzero
	lw a0, 8(sp)
	lw a1, 12(sp)
	call strnlen
	mv a2, a0
	sb zero, 0(a0) # dst[strlen(src)] = '\0'
	lw a1, 8(sp)
	lw a0, 4(sp)
	call memcpy
	lw ra, 0(sp)
	addi sp, sp,  16 # Leave stack frame
	ret

strcspn:
	## args
	# a0 = const char *s
	# a1 = const char *reject
	## local
	# t0 = temporary address, buffer
	# t1 = iterator i
	# t2 = iterator j
	# t3 = temporary address, buffer
	## return
	# a0 = returns the number of bytes in the initial segment of s which are not in the string reject.

	li t1, 0
	li t2, 0
1:
	add t0, a0, t1
	lb t0, 0(t0)
	beqz t0, 3f
2:
	add t3, a1, t2
	lb t3, 0(t3)
	beqz t3, 2f
	addi t2, t2, 1
	bne t0, t3, 2b
2:
	addi t1, t1, 1
	j 1b
3:
	mv a0, t1
	ret

strerror:
	UNIMP
	ret

strlen:
	## args
	# a0 = const char *str
	## local
	# t0 = temporary address, buffer
	# t1 = iterator
	## return
	# a0 = length of string, excluded NUL character.
	li t1, 0
1:
	add t0, a0, t1
	lb t0, 0(t0)
	beqz t0, 1f
	addi t1, t1, 1
	j 1b
1:
	mv a0, t1
	ret

strnlen:
	## args
	# a0 = const char *str
	# a1 = size_t maxlen
	## local
	# t0 = temporary address, buffer
	# t1 = iterator
	## return
	# a0 = length of string, excluded NUL character

	li t1, 0
1:
	bgeu t1, a1, 1f
	add t0, a0, t1
	lb t0, 0(t0)
	beqz t0, 1f
	addi t1, t1, 1
	j 1b
1:
	mv a0, t1
	ret

strpbrk:
	UNIMP
	ret
strrchr:
	UNIMP
	ret

strspn:
	## args
	# a0 = const char *s
	# a1 = const char *accept
	## local
	# t0 = temporary address, buffer
	# t1 = iterator i
	# t2 = iterator j
	# t3 = temporary address, buffer
	## return
	# a0 = returns the number of bytes in the initial segment of s which are not in the string reject.

	li t1, 0
	li t2, 0
1:
	add t0, a0, t1
	lb t0, 0(t0)
	beqz t0, 3f
2:
	add t3, a1, t2
	lb t3, 0(t3)
	beqz t3, 2f
	addi t2, t2, 1
	beq t0, t3, 2b
2:
	addi t1, t1, 1
	j 1b
3:
	mv a0, t1
	ret

strstr:
	## args
	# a0 = const char *haystack
	# a1 = const char *needle
	## local
	# t0 = temporary address, buffer
	# t1 = iterator i
	# t2 = iterator j
	# t3 = temporary address, buffer
	## return
	# a0 = return a pointer to the beginning of the located substring, or NULL if the substring is not found. If needle is the empty string, the return value is always haystack itself.

	li t1, 0
	li t2, 0
1:
	add t0, a0, t1
	lb t0, 0(t0)
	beqz t0, 4f
2:
	add t3, a1, t2
	lb t3, 0(t3)
	addi t2, t2, 1
	beqz t3, 3f
	beq t0, t3, 2b
	addi t1, t1, 1
	j 1b
3:
	add a0, a0, t1
4:
	ret

strtok:
	## args
	# a0 = char *restrict str
	# a1 = const char *restrict delim
	## local
	## return
	# a0 = return a pointer to the next token, or NULL if there are no more tokens.
	UNIMP
	ret
	li t1, 0
	li t2, 0
	bnez a0, 1f # If a0 is not null, then start the new state
	la a0, _strtok_cur_ptr # Load current state ptr
	lw a0, 0(a0)
1:
	add t0, a0, t1
	lb t0, 0(t0)
	beqz t0, 4f
2:
	add t3, a1, t2
	lb t3, 0(t3)
	beqz t3, 2f
	addi t2, t2, 1
	beq t0, t3, 3f
2:
	addi t1, t1, 1
	j 1b
3:
	la t0, _strtok_cur_ptr
	add t3, a0,

4:
	li a0, NULL
	ret



	la t3, _strtok_cur_ptr
	sw t2, 0(t3) # Store current state
	lw a0, 4(sp)
	j 2f
1:
	li a0, NULL
2:
	lw ra, 0(sp)
	addi sp, sp,  16 # Leave stack frame
	ret


strxfrm:
	UNIMP
	ret
