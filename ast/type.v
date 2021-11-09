module ast

pub type Type = Pointer | Array | Function | BaseType

pub struct Pointer {
pub mut:
	number int
	base Type
}

pub struct Array {
pub mut:
	number int
	base Type
}

pub struct Function {
pub mut:
	args []FuncArgs
	base Type
}

pub struct FuncArgs {
mut:
	name string
	typ Type
}

pub type BaseType = Numerical | Struct | Union | Enum

pub enum Numerical {
	void
	char
	schar
	uchar
	short
	ushort
	int
	uint
	long
	ulong
	longlong
	ulonglong
	bool
}

pub struct Struct {}

pub struct Union {}

pub struct Enum {}
