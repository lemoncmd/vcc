module parser

import ast

struct DeclPair {
	typ ast.Type
	name string
}

[params]
struct RTEParams {
	consume_comma bool
}

fn (mut p Parser) read_type_extend(base ast.BaseType, params RTEParams) []DeclPair {
	mut pairs := []DeclPair{}
	for {
		mut typ := ast.Type(base)
		mut types, name := p.read_type_internal()
		for typ_out_ in types {
			match typ_out_ {
				ast.Pointer {
					mut typ_out := typ_out_
					typ_out.base = typ
					typ = typ_out
				}
				ast.Array {
					mut typ_out := typ_out_
					typ_out.base = typ
					typ = typ_out
				}
				ast.Function {
					mut typ_out := typ_out_
					typ_out.base = typ
					typ = typ_out
				}
				else{}
			}
		}
		pairs << DeclPair{typ:typ, name:name}
		if p.tok.kind == .comma {
			p.next()
		} else {
			break
		}
	}
	return pairs
}

fn (mut p Parser) read_type_internal() ([]ast.Type, string) {
	mut types := []ast.Type{}
	mut pointer := 0
	for p.tok.kind == .mul {
		pointer++
		p.next()
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
	}
	for {
		match p.tok.kind {
			.lpar {
				p.next()
				types << p.read_type_function()
			}
			.lsbr {
				p.next()
				//TODO const expr
				number := if p.tok.kind == .num {
					p.tok.str.int()
				} else {-1}
				if p.tok.kind != .rsbr {
					p.token_err('Expected `]`')
				}
				types << ast.Array{number:number}
			}
			else {break}
		}
	}
	if pointer > 0 {
		types << ast.Array{number:pointer}
	}
	return types, name
}

fn (mut p Parser) read_type_function() ast.Function {
	if p.tok.kind != .rpar {
		p.token_err('Expected `)`')
	}
	p.next()
	return ast.Function{}
}

enum BaseType4Read {
	non
	int
	char
} // will be float and double

fn (mut p Parser) read_base_type() ast.BaseType {
	mut long := 0
	mut short := 0
	mut signed := 0
	mut unsigned := 0
	mut base_typ := BaseType4Read.non
	for {
		match p.tok.kind {
			.k_int {
				if base_typ == .char {
					p.token_err('Cannot combine `int` and `short`')
				}
				base_typ = .int
			}
			.k_char {
				if base_typ == .int {
					p.token_err('Cannot combine `int` and `short`')
				}
				base_typ = .char
			}
			.k_long { long++ }
			.k_short { short++ }
			.k_signed { signed++ }
			.k_unsigned { unsigned++ }
			.k_const {}
			else {break}
		}
		p.next()
	}

	// error process
	if base_typ == .char {
		if long > 0 {
			p.token_err('`' + 'long '.repeat(long) + 'char` is invalid')
		}
		if short > 0 {
			p.token_err('`' + 'short '.repeat(long) + 'char` is invalid')
		}
	}
	if short > 0 && long > 0 {
		p.token_err('Cannot combine `long` and `short`')
	}
	if long > 2 {
		p.token_err('`' + 'long '.repeat(long) + 'int` is too long for the compiler')
	}
	if signed > 0 && unsigned > 0 {
		p.token_err('Cannot combine `signed` and `unsigned`')
	}

	return ast.BaseType(if base_typ == .char {
		if signed > 0 {
			ast.Numerical.schar
		} else if unsigned > 0 {
			ast.Numerical.uchar
		} else {
			ast.Numerical.char
		}
	} else {
		ast.Numerical.int
	})
}
