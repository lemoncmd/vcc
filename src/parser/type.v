module parser

import ast
import token

struct DeclPair {
	typ  ast.Type
	name string
}

[params]
struct RTEParams {
	consume_comma bool
}

fn (mut p Parser) read_type_extend(base ast.BaseType, params RTEParams) []DeclPair {
	mut pairs := []DeclPair{}
	for {
		mut typ := ast.Type{base: base}
		mut types, name := p.read_type_internal()
		typ.decls << types
		pairs << DeclPair{
			typ: typ
			name: name
		}
		if params.consume_comma && p.tok.kind == .comma {
			p.next()
		} else {
			break
		}
	}
	return pairs
}

fn (mut p Parser) read_type_internal() ([]ast.Declarator, string) {
	mut types := []ast.Declarator{}
	for p.tok.kind == .mul {
		p.next()
		is_const := p.tok.kind == .k_const
		types << ast.Pointer {
			is_const: is_const
		}
		if is_const {
			p.next()
		}
	}
	mut name := ''
	if p.tok.kind == .lpar {
		p.next()
		if p.tok.kind.is_keyword() || p.tok.kind == .rpar {
			types << p.read_type_function()
		} else {
			types, name = p.read_type_internal()
		}
	} else if p.tok.kind == .ident {
		name = p.tok.str
		p.next()
	}
	for {
		match p.tok.kind {
			.lpar {
				p.next()
				types << p.read_type_function()
			}
			.lcbr {
				p.next()
				mut stat := p.tok.kind == .k_static
				if stat {
					p.next()
				}
				for (p.tok.kind in [.k_const, .k_restrict, .k_volatile]) {
					p.next()
				}
				if !stat && p.tok.kind == .k_static {
					stat = true
					p.next()
				}
				// TODO const expr
				number := if p.tok.kind == .num {
					ret := p.tok.str.int()
					p.next()
					ret
				} else if p.tok.kind == .mul && !stat {
					p.next()
					(-2)
				} else {
					-1
				}
				p.check(.rcbr)
				p.next()
				types << ast.Array{
					number: number
				}
			}
			else {
				break
			}
		}
	}
	return types, name
}

fn (mut p Parser) read_type_function() ast.Function {
	mut is_extensible := true
	mut args := []ast.FuncArgs{}
	for p.tok.kind != .rpar {
		if p.tok.kind == .tridot {
			p.next()
			break
		} else {
			is_extensible = false
		}
		decl := p.read_type_extend(p.read_base_type())[0]
		args << ast.FuncArgs{
			name: decl.name
			typ: decl.typ
		}
		if p.tok.kind != .comma {
			break
		}
		p.next()
		if p.tok.kind == .rpar {
			p.token_err('Expected argument')
		}
	}
	p.check(.rpar)
	p.next()
	return ast.Function{
		args: args
		is_extensible: is_extensible
	}
}

// will be float and double
enum BaseType4Read {
	non
	void
	int
	char
	float
	double
	bool
}

fn (b BaseType4Read) str() string {
	return match b {
		.non { 'int' }
		.void { 'void' }
		.int { 'int' }
		.char { 'char' }
		.float { 'float' }
		.double { 'double' }
		.bool { 'bool' }
	}
}

fn tok2base(tok token.Kind) BaseType4Read {
	return match tok {
		.k_void { BaseType4Read.void }
		.k_int { BaseType4Read.int }
		.k_char { BaseType4Read.char }
		.k_float { BaseType4Read.float }
		.k_double { BaseType4Read.double }
		.k_bool { BaseType4Read.bool }
		else { BaseType4Read.non }
	}
}

[inline; noreturn]
fn (p Parser) adjective_err(base BaseType4Read, long int, short int, signed int, unsigned int, complex int) {
	p.token_err('`' + 'long '.repeat(long) + 'short '.repeat(short) + 'signed '.repeat(signed) +
		'unsigned '.repeat(unsigned) + '_Complex'.repeat(complex) + '$base` is invalid')

	// V BUG with noreturn
	for {}
}

fn (mut p Parser) read_base_type() ast.BaseType {
	mut long := 0
	mut short := 0
	mut signed := 0
	mut unsigned := 0
	mut complex := 0
	mut base_typ := BaseType4Read.non
	for (p.tok.kind in [.k_const, .k_restrict, .k_volatile]) {
		p.next()
	}
	if p.tok.kind == .ident {
		name := p.tok.str
		for (p.tok.kind in [.k_const, .k_restrict, .k_volatile]) {
			p.next()
		}
		return ast.Deftype{
			name: name
		}
	}
	// TODO struct def
	if p.tok.kind in [.k_struct, .k_union] {
		strc := p.read_struct_type()
		for (p.tok.kind in [.k_const, .k_restrict, .k_volatile]) {
			p.next()
		}
		return strc
	}
	if p.tok.kind == .k_enum {
		enm := p.read_enum_type()
		for (p.tok.kind in [.k_const, .k_restrict, .k_volatile]) {
			p.next()
		}
		return enm
	}
	for {
		match p.tok.kind {
			.k_void, .k_int, .k_char, .k_float, .k_double, .k_bool {
				if base_typ != .non {
					p.token_err('Cannot combine `${tok2base(p.tok.kind)}` and `$base_typ`')
				}
				base_typ = tok2base(p.tok.kind)
			}
			.k_long {
				long++
			}
			.k_short {
				short++
			}
			.k_signed {
				signed++
			}
			.k_unsigned {
				unsigned++
			}
			.k_const, .k_restrict, .k_volatile {}
			else {
				break
			}
		}
		p.next()
	}

	// error process
	match base_typ {
		.non, .int {
			if long > 2 || complex > 0 {
				p.adjective_err(base_typ, long, short, signed, unsigned, complex)
			}
		}
		.char {
			if (long + short + complex) > 0 {
				p.adjective_err(base_typ, long, short, signed, unsigned, complex)
			}
		}
		.float {
			if (long + short + signed + unsigned) > 0 {
				p.adjective_err(base_typ, long, short, signed, unsigned, complex)
			}
		}
		.double {
			if long > 1 || (short + signed + unsigned) > 0 {
				p.adjective_err(base_typ, long, short, signed, unsigned, complex)
			}
		}
		.void, .bool {
			if (long + short + signed + unsigned + complex) > 0 {
				p.adjective_err(base_typ, long, short, signed, unsigned, complex)
			}
		}
	}
	if short > 0 && long > 0 {
		p.token_err('Cannot combine `long` and `short`')
	}
	if signed > 0 && unsigned > 0 {
		p.token_err('Cannot combine `signed` and `unsigned`')
	}

	return match base_typ {
		.void {
			ast.Numerical.void
		}
		.char {
			if signed > 0 {
				ast.Numerical.schar
			} else if unsigned > 0 {
				ast.Numerical.uchar
			} else {
				ast.Numerical.char
			}
		}
		.int, .non {
			if short > 0 {
				if unsigned > 0 {
					ast.Numerical.ushort
				} else {
					ast.Numerical.short
				}
			} else if long == 1 {
				if unsigned > 0 {
					ast.Numerical.ulong
				} else {
					ast.Numerical.long
				}
			} else if long > 1 {
				if unsigned > 0 {
					ast.Numerical.ulonglong
				} else {
					ast.Numerical.longlong
				}
			} else {
				if unsigned > 0 {
					ast.Numerical.uint
				} else {
					ast.Numerical.int
				}
			}
		}
		.float {
			if complex > 1 {
				ast.Numerical.floatc
			} else {
				ast.Numerical.float
			}
		}
		.double {
			if complex > 1 {
				if long > 1 {
					ast.Numerical.ldoublec
				} else {
					ast.Numerical.doublec
				}
			} else {
				if long > 1 {
					ast.Numerical.ldouble
				} else {
					ast.Numerical.double
				}
			}
		}
		.bool {
			ast.Numerical.bool
		}
	}
}

fn (mut p Parser) read_struct_type() ast.BaseType {
	which := p.tok.kind
	p.next()
	name := if p.tok.kind == .ident {
		str := p.tok.str
		p.next()
		str
	} else {
		''
	}
	// name only
	if p.tok.kind != .lsbr {
		if name == '' {
			p.token_err('Expected identifier or `{`')
		}
		if which == .k_struct {
			if strc := p.structs[name] {
				return strc
			}
			p.structs[name] = ast.Struct{
				name: name
				table: &ast.StructTable{}
			}
		} else {
			if unon := p.unions[name] {
				return unon
			}
			p.unions[name] = ast.Union{
				name: name
				table: &ast.StructTable{}
			}
		}
	}
	// definition
	p.next()
	mut found := false
	mut table := &ast.StructTable{}
	// find table
	if name != '' {
		if which == .k_struct {
			if strc := p.structs[name] {
				table = strc.table
			}
		} else {
			if unon := p.unions[name] {
				table = unon.table
			}
		}
		if table.defined {
			p.token_err('`' + if which == .k_struct { 'struct' } else { 'union' } +
				' $name` is already defined')
		}
	}
	// register struct
	if !found && name != '' {
		if which == .k_struct {
			// TODO let define struct in block
			p.structs[name] = ast.Struct{
				name: name
				table: table
			}
		} else {
			p.unions[name] = ast.Union{
				name: name
				table: table
			}
		}
	}
	table.defined = true
	for p.tok.kind != .rsbr {
		// TODO
		if p.tok.kind == .eof {
			p.check(.rsbr)
		}
		decls := p.read_type_extend(p.read_base_type(),
			consume_comma: true
		)
		for decl in decls {
			if !decl.typ.is_complete_type() {
				p.token_err('Cannot use incomplete type as struct field')
			}
			if decl.typ.decls.last() is ast.Function {
				p.token_err('Cannot use function as struct field')
			}
			table.fields << ast.Field{
				typ: decl.typ
				name: decl.name
			}
		}
		p.check(.semi)
		p.next()
	}
	p.next()
	return if which == .k_struct { ast.BaseType(ast.Struct{
			name: name
			table: table
		}) } else { ast.BaseType(ast.Union{
			name: name
			table: table
		}) }
}

// TODO
fn (mut p Parser) read_enum_type() ast.BaseType {
	p.next()
	/*name := if p.tok.kind == .ident {
		str := p.tok.str
		p.next()
		str
	} else {
		''
	}*/
	return ast.Enum{}
}