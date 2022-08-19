module ast

pub struct Type {
pub mut:
	base  BaseType
	qual  Qualifier
	decls []Declarator
}

pub struct TypeIter {
	typ Type
mut:
	count int
}

pub fn (t Type) iter() TypeIter {
	return TypeIter{
		typ: t
		count: t.decls.len
	}
}

pub fn (mut i TypeIter) next() ?Declarator {
	i.count--
	if i.count < 0 {
		return none
	}
	return i.typ.decls[i.count]
}

pub enum Storage {
	default
	auto
	register
	@static
	extern
	typedef
}

pub struct Qualifier {
pub mut:
	is_const    bool
	is_volatile bool
	is_restrict bool
}

pub type Declarator = Array | Function | Pointer

pub struct Pointer {
pub mut:
	is_const bool
}

pub struct Array {
pub mut:
	number int
}

pub struct Function {
pub mut:
	args          []FuncArgs
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
	for d in t.iter() {
		return match d {
			Pointer {
				true
			}
			Array {
				d.number >= 0
			}
			Function {
				true
			}
		}
	}
	return match t.base {
		Numerical {
			t.base != .void
		}
		else {
			false
		}
	}
}
