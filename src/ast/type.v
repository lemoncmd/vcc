module ast

pub type Type = Array | BaseType | Function | Pointer

pub struct Pointer {
pub mut:
	number int
	base   Type
}

pub struct Array {
pub mut:
	number int
	base   Type
}

pub struct Function {
pub mut:
	args          []FuncArgs
	base          Type
	is_extensible bool
}

pub struct FuncArgs {
mut:
	name string
	typ  Type
}

pub type BaseType = Deftype | Enum | Numerical | Struct | Union

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
	float
	double
	ldouble
	bool
	floatc
	doublec
	ldoublec
}

pub struct Struct {
	name string
pub mut:
	table &StructTable
}

pub struct Union {
	name string
pub mut:
	table &StructTable
}

[heap]
pub struct StructTable {
pub mut:
	defined bool
	fields  []Field
}

pub struct Field {
	name string
	typ  Type
}

pub struct Enum {}

pub struct Deftype {
pub:
	name string
}

pub fn (t Type) is_complete_type() bool {
	return match t {
		Pointer {
			true
		}
		BaseType {
			match t {
				Numerical {
					t != .void
				}
				else {
					false
				}
			}
		}
		Array {
			t.number >= 0
		}
		Function {
			true
		}
	}
}
