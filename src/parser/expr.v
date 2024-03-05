module parser

import ast

fn (mut p Parser) expr() ast.Expr {
	mut node := p.assign()
	for {
		if p.tok.kind == .comma {
			p.next()
			node = ast.BinaryExpr{
				op: .comma
				left: node
				right: p.assign()
			}
		} else {
			break
		}
	}
	return node
}

fn (mut p Parser) assign() ast.Expr {
	mut node := p.ternary()
	if p.tok.kind.is_assign() {
		op := p.tok.kind
		p.next()
		node = ast.BinaryExpr{
			op: op
			left: node
			right: p.assign()
		}
	}
	return node
}

fn (mut p Parser) ternary() ast.Expr {
	mut node := p.logor()
	if p.tok.kind == .question {
		p.next()
		expr_true := p.expr()
		p.check(.colon)
		p.next()
		node = ast.TernaryExpr{
			cond: node
			left: expr_true
			right: p.ternary()
		}
	}
	return node
}

fn (mut p Parser) logor() ast.Expr {
	mut node := p.logand()
	for {
		if p.tok.kind == .lor {
			p.next()
			node = ast.BinaryExpr{
				op: .lor
				left: node
				right: p.logand()
			}
		} else {
			break
		}
	}
	return node
}

fn (mut p Parser) logand() ast.Expr {
	mut node := p.bitor()
	for {
		if p.tok.kind == .land {
			p.next()
			node = ast.BinaryExpr{
				op: .land
				left: node
				right: p.bitor()
			}
		} else {
			break
		}
	}
	return node
}

fn (mut p Parser) bitor() ast.Expr {
	mut node := p.bitxor()
	for {
		if p.tok.kind == .aor {
			p.next()
			node = ast.BinaryExpr{
				op: .aor
				left: node
				right: p.bitxor()
			}
		} else {
			break
		}
	}
	return node
}

fn (mut p Parser) bitxor() ast.Expr {
	mut node := p.bitand()
	for {
		if p.tok.kind == .xor {
			p.next()
			node = ast.BinaryExpr{
				op: .xor
				left: node
				right: p.bitand()
			}
		} else {
			break
		}
	}
	return node
}

fn (mut p Parser) bitand() ast.Expr {
	mut node := p.equality()
	for {
		if p.tok.kind == .aand {
			p.next()
			node = ast.BinaryExpr{
				op: .aand
				left: node
				right: p.equality()
			}
		} else {
			break
		}
	}
	return node
}

fn (mut p Parser) equality() ast.Expr {
	mut node := p.relational()
	for {
		if p.tok.kind in [.eq, .ne] {
			op := p.tok.kind
			p.next()
			node = ast.BinaryExpr{
				op: op
				left: node
				right: p.relational()
			}
		} else {
			break
		}
	}
	return node
}

fn (mut p Parser) relational() ast.Expr {
	mut node := p.shift()
	for {
		if p.tok.kind in [.gt, .ge, .lt, .le] {
			op := p.tok.kind
			p.next()
			node = ast.BinaryExpr{
				op: op
				left: node
				right: p.shift()
			}
		} else {
			break
		}
	}
	return node
}

fn (mut p Parser) shift() ast.Expr {
	mut node := p.add()
	for {
		if p.tok.kind in [.lshift, .rshift] {
			op := p.tok.kind
			p.next()
			node = ast.BinaryExpr{
				op: op
				left: node
				right: p.add()
			}
		} else {
			break
		}
	}
	return node
}

fn (mut p Parser) add() ast.Expr {
	mut node := p.mul()
	for {
		if p.tok.kind in [.plus, .minus] {
			op := p.tok.kind
			p.next()
			node = ast.BinaryExpr{
				op: op
				left: node
				right: p.mul()
			}
		} else {
			break
		}
	}
	return node
}

fn (mut p Parser) mul() ast.Expr {
	mut node := p.cast()
	for {
		if p.tok.kind in [.mul, .div, .mod] {
			op := p.tok.kind
			p.next()
			node = ast.BinaryExpr{
				op: op
				left: node
				right: p.cast()
			}
		} else {
			break
		}
	}
	return node
}

fn (mut p Parser) cast() ast.Expr {
	if p.tok.kind == .lpar {
		p.next()
		if p.tok.kind.is_type_keyword() { // TODO
			typ := p.read_type_name()
			p.check(.rpar)
			p.next()
			return ast.CastExpr{
				typ: typ
				left: p.unary()
			}
		} else {
			expr := p.expr()
			p.check(.rpar)
			p.next()
			return expr
		}
	}
	return p.unary()
}

fn (mut p Parser) unary() ast.Expr {
	op := p.tok.kind
	match op {
		.k_sizeof {
			p.next()
			if p.tok.kind == .lpar {
				p.next()
				if p.tok.kind.is_keyword() { // TODO is type
					base, storage := p.read_base_type()
					typ := p.read_type_extend(base, storage)[0]
					if typ.storage != .default {
						p.token_err('Illegal storage class specifier')
					}
					if typ.name != '' {
						p.token_err('Unexpected name')
					}
					p.check(.rpar)
					p.next()
					return ast.SizeofExpr(typ.typ)
				} else {
					expr := p.expr()
					p.check(.rpar)
					p.next()
					return ast.SizeofExpr(expr)
				}
			}
			return ast.SizeofExpr(p.unary())
		}
		.mul {
			p.next()
			return ast.DerefExpr{
				left: p.unary()
			}
		}
		.aand, .plus, .minus, .anot, .lnot {
			p.next()
			return ast.UnaryExpr{
				op: op
				left: p.unary()
			}
		}
		.inc, .dec {
			p.next()
			return ast.CrementExpr{
				op: op
				is_front: true
				left: p.unary()
			}
		}
		else {
			return p.postfix()
		}
	}
}

fn (mut p Parser) postfix() ast.Expr {
	mut node := p.primary()
	// println(node)
	for {
		op := p.tok.kind
		match op {
			.inc, .dec {
				p.next()
				node = ast.CrementExpr{
					op: op
					is_front: false
					left: node
				}
			}
			.lcbr {
				p.next()
				expr := p.expr()
				p.check(.rcbr)
				p.next()
				node = ast.DerefExpr{
					left: ast.BinaryExpr{
						op: .plus
						left: node
						right: expr
					}
				}
			}
			.lpar {
				p.next()
				mut args := []ast.Expr{}
				for p.tok.kind != .rpar {
					args << p.assign()
					if p.tok.kind != .comma {
						break
					}
					p.next()
					if p.tok.kind == .rpar {
						p.token_err('Expected expression')
					}
				}
				p.check(.rpar)
				p.next()
				node = ast.CallExpr{
					left: node
					args: args
				}
			}
			.dot {
				p.next()
				p.check(.ident)
				name := p.tok.str
				p.next()
				return ast.SelectorExpr{
					left: node
					field: name
				}
			}
			.arrow {
				p.next()
				p.check(.ident)
				name := p.tok.str
				p.next()
				return ast.DerefExpr{
					left: ast.SelectorExpr{
						left: node
						field: name
					}
				}
			}
			else {
				break
			}
		}
	}
	return node
}

fn (mut p Parser) primary() ast.Expr {
	match p.tok.kind {
		.lpar {
			p.next()
			node := p.expr()
			p.check(.rpar)
			p.next()
			return node
		}
		.ident {
			name := p.tok.str
			p.next()
			mut scopeid := p.curscope
			for scopeid != -1 {
				scope := p.curscopes[scopeid]
				if name in scope.types {
					return ast.LvarLiteral{
						name: name
					}
				}
				scopeid = scope.parent
			}
			return ast.GvarLiteral{
				name: name
			}
		}
		.num {
			val := p.tok.str.u64()
			p.next()
			return ast.IntegerLiteral{
				val: val
			}
		}
		.str {
			str := p.tok.str
			p.next()
			return ast.StringLiteral{
				val: str
			}
		}
		.k_generic {
			p.next()
			p.check(.lpar)
			p.next()
			expr := p.assign()
			mut cases := []ast.GenericCase{}
			for p.tok.kind != .rpar {
				typ := if p.tok.kind == .k_default {
					p.next()
					ast.GenericAssociation(ast.GenericDefault{})
				} else {
					ast.GenericAssociation(p.read_type_name())
				}
				p.check(.colon)
				p.next()
				cases << ast.GenericCase{
					typ: typ
					expr: p.assign()
				}
			}
			return ast.GenericExpr{
				expr: expr
				cases: cases
			}
		}
		else {
			p.token_err('Expected primary')
			return p.primary()
		}
	}
}
