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
	println(p.funs)
}

fn (mut p Parser) function(typ ast.Type) ast.FunctionDecl {
	body := p.stmt()
	if body !is ast.BlockStmt {
		p.token_err('Expected Block')
	}
	return ast.FunctionDecl{
		typ: typ
		body: body as ast.BlockStmt
	}
}

fn (mut p Parser) stmt() ast.Stmt {
	match p.tok.kind {
		.k_return {
			p.next()
			node := ast.ReturnStmt{expr: p.expr()}
			p.check(.semi)
			p.next()
			return node
		}
		.lsbr {
			p.next()
			mut stmts := []ast.Stmt{}
			for p.tok.kind != .rsbr {
				if p.tok.kind == .eof {
					p.token_err('Expected `}`')
				}
				stmts << p.stmt()
			}
			p.next()
			return ast.BlockStmt{stmts:stmts}
		}
		.k_if {
			p.next()
			p.check(.lpar)
			p.next()
			expr := p.expr()
			p.check(.rpar)
			p.next()
			stmt_true := p.stmt()
			return ast.IfStmt{
				cond: expr
				stmt: stmt_true
				else_stmt: if p.tok.kind == .k_else {
					p.next()
					p.stmt()
				} else {
					ast.Stmt(ast.EmptyStmt{})
				}
			}
		}
		.k_for {}
		.k_while {
			p.next()
			p.check(.lpar)
			p.next()
			expr := p.expr()
			p.check(.rpar)
			p.next()
			return ast.WhileStmt{
				cond: expr
				stmt: p.stmt()
			}
		}
		.k_do {
			p.next()
			stmt := p.stmt()
			p.check(.k_while)
			p.next()
			p.check(.lpar)
			p.next()
			expr := p.expr()
			p.check(.rpar)
			p.next()
			p.check(.semi)
			p.next()
			return ast.DoStmt{
				cond: expr
				stmt: stmt
			}
		}
		.k_switch {}
		.k_break {
			p.next()
			p.check(.semi)
			p.next()
			return ast.BreakStmt{}
		}
		.k_continue {
			p.next()
			p.check(.semi)
			p.next()
			return ast.ContinueStmt{}
		}
		.k_goto {}
		.k_case {}
		.k_default {}
		.semi {
			p.next()
			return ast.EmptyStmt{}
		}
		else {
			if p.tok.kind.is_keyword() {
				base_typ := p.read_base_type()
				for {
					extend := p.read_type_extend(base_typ)[0] or {break}
					if p.tok.kind == .assign {
						p.next()
						expr := p.expr()
					}
					if p.tok.kind == .semi {
						break
					} else {
						p.check(.comma)
						p.next()
					}
				}
				p.check(.semi)
				p.next()
				return ast.DeclStmt{decls:[]}
			} else {
				expr := p.expr()
				p.check(.semi)
				p.next()
				return ast.ExprStmt{expr: expr}
			}
		}
	}
	return ast.EmptyStmt{}
}
