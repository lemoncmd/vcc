module x8664

import ast

fn get_type_size(typ ast.Type) int {
	mut size := match typ.base {
		ast.Numerical {
			match typ.base {
				.char, .schar, .uchar, .bool { 1 }
				.short, .ushort { 2 }
				.int, .uint, .float { 4 }
				.long, .ulong, .longlong, .ulonglong, .double, .floatc { 8 }
				.ldouble, .doublec { 16 }
				.ldoublec { 32 }
			}
		}
		else {
			0
		}
	}
	if typ.decls.len != 0 {
		match typ.decls.last() {
			ast.Function {
				size = 0
			}
			ast.Pointer {
				size = 8
			}
			ast.Array {
				for decl in typ.decls {
					match decl {
						ast.Function { size = 0 }
						ast.Pointer { size = 8 }
						ast.Array { size *= decl.number }
					}
				}
			}
		}
	}
	// TODO incomplete
	if size == 0 {
		size = 1
	}
	return size
}

fn get_pointer_type_size(typ_ ast.Type) int {
	mut typ := typ_
	typ.decls = typ_.decls.clone()
	if typ.decls.last() !is ast.Function {
		typ.decls.pop()
	}
	return get_type_size(typ)
}

fn get_type_align(typ ast.Type) int {
	// TODO struct
	return get_type_size(typ)
}

fn get_size_str(size int) string {
	return match size {
		1 { 'byte' }
		2 { 'word' }
		4 { 'dword' }
		8 { 'qword' }
		else { 'NONE' }
	}
}

fn (mut g Gen) set_fn_offset() int {
	mut curoff := 0
	for mut scope in g.curfn_scope {
		for name, typ in scope.types {
			size := get_type_size(typ)
			align := get_type_align(typ)
			curoff += size
			curoff = (curoff + align - 1) / align * align
			scope.offset[name] = curoff
		}
	}
	return curoff
}
