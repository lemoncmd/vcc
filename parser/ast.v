module parser

import ast

pub fn (mut p Parser) top() {
	for p.tok.kind != .eof {
		base_typ := p.read_base_type()
		decls := p.read_type_extend(base_typ, consume_comma: true)
		match p.tok.kind {
			.lsbr {
				if decls.len == 0 || decls[0].name == '' {
					p.token_err('Expected identifier')
				}
				if decls.len > 1 || decls[0].typ !is ast.Function {
					p.token_err('Expected `;` after top level declaration')
				}
				p.next()
				p.funs[decls[0].name] = p.function(decls[0].typ)
			}
			.semi {
				p.next()
			}
			else {
				p.token_err('Expected `;` after top level declaration')
			}
		}
	}
}

fn (mut p Parser) function(typ ast.Type) ast.FunctionDecl {
	if p.tok.kind != .rsbr {
		p.token_err('Expected `}`')
	}
	p.next()
	return ast.FunctionDecl{typ: typ}
}
