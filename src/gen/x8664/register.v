module x8664

enum Register {
	rax
	rcx
	rdx
	rbx
	rsp
	rbp
	rsi
	rdi
	r8
	r9
	r10
	r11
	r12
	r13
	r14
	r15
}

const regs = [Register.rdi, .rsi, .rdx, .rcx, .r8, .r9]

const reg_to_sized_reg = [
	['al', 'cl', 'dl', 'bl', 'spl', 'bpl', 'sil', 'dil', 'r8b', 'r9b', 'r10b', 'r11b', 'r12b',
		'r13b', 'r14b', 'r15b'],
	['ax', 'cx', 'dx', 'bx', 'sp', 'bp', 'si', 'di', 'r8w', 'r9w', 'r10w', 'r11w', 'r12w', 'r13w',
		'r14w', 'r15w'],
	['eax', 'ecx', 'edx', 'ebx', 'esp', 'ebp', 'esi', 'edi', 'r8d', 'r9d', 'r10d', 'r11d', 'r12d',
		'r13d', 'r14d', 'r15d'],
	['rax', 'rcx', 'rdx', 'rbx', 'rsp', 'rbp', 'rsi', 'rdi', 'r8', 'r9', 'r10', 'r11', 'r12', 'r13',
		'r14', 'r15'],
]

fn get_register(reg Register, size int) string {
	return match size {
		1 { x8664.reg_to_sized_reg[0][int(reg)] }
		2 { x8664.reg_to_sized_reg[1][int(reg)] }
		4 { x8664.reg_to_sized_reg[2][int(reg)] }
		8 { x8664.reg_to_sized_reg[3][int(reg)] }
		else { '' }
	}
}
