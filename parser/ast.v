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
		.k_return { // TODO empty return
			p.next()
			node := ast.ReturnStmt{
				expr: p.expr()
			}
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
				stmts << if p.tok.kind.is_keyword() { p.declaration() } else { p.stmt() }
			}
			p.next()
			return ast.BlockStmt{
				stmts: stmts
			}
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
		.k_for {
			p.next()
			p.check(.lpar)
			p.next()
			mut first := ast.Stmt(ast.EmptyStmt{})
			if p.tok.kind.is_keyword() { // TODO definition
				typ := p.read_type_extend(p.read_base_type())[0]
			} else if p.tok.kind != .semi {
				first = ast.ExprStmt{
					expr: p.expr()
				}
			}
			p.check(.semi)
			p.next()
			cond := if p.tok.kind == .semi { ast.Expr(ast.IntegerLiteral{
					val: 1
				}) } else { p.expr() }
			p.check(.semi)
			p.next()
			last := if p.tok.kind == .rpar { ast.Expr(ast.IntegerLiteral{
					val: 0
				}) } else { p.expr() }
			p.check(.rpar)
			p.next()
			return ast.ForStmt{
				first: first
				cond: cond
				next: last
				stmt: p.stmt()
			}
		}
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
		.k_switch {
			p.next()
			p.check(.lpar)
			p.next()
			cond := p.expr()
			p.check(.rpar)
			p.next()
			mut switch := ast.SwitchStmt{
				cond: cond
			}
			p.switchs << switch
			stmt := p.stmt()
			switch = p.switchs.pop()
			switch.stmt = stmt
			return switch
		}
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
		.k_goto {
			p.next()
			p.check(.ident)
			name := p.tok.str
			p.next()
			p.check(.semi)
			p.next()
			return ast.GotoStmt{
				name: name
			}
		}
		.k_case {
			p.next()
			cond := p.expr()
			p.check(.colon)
			p.next()
			if p.switchs.len == 0 {
				p.token_err('Cannot write `case` out of switch statement')
			}
			case := ast.CaseStmt{
				expr: cond
				stmt: p.stmt()
			}
			p.switchs[0].cases << case
			return case
		}
		.k_default {
			p.next()
			p.check(.colon)
			p.next()
			if p.switchs.len == 0 {
				p.token_err('Cannot write `default` out of switch statement')
			}
			def := ast.DefaultStmt{
				stmt: p.stmt()
			}
			p.switchs[0].cases << def
			return def
		}
		.semi {
			p.next()
			return ast.EmptyStmt{}
		}
		else {
			if p.tok.kind == .ident {
				name := p.tok
				p.next()
				if p.tok.kind == .colon {
					p.next()
					return ast.LabelStmt{
						name: name.str
						stmt: p.stmt()
					}
				}
				p.tok = name
				p.pos--
			}
			expr := p.expr()
			p.check(.semi)
			p.next()
			return ast.ExprStmt{
				expr: expr
			}
		}
	}
	return ast.EmptyStmt{}
}

fn (mut p Parser) declaration() ast.Stmt {
	base_typ := p.read_base_type()
	for {
		extend := p.read_type_extend(base_typ)[0] or { break }
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
	return ast.DeclStmt{
		decls: []
	}
}
