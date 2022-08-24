module parser

import ast

pub fn (mut p Parser) top() {
	for p.tok.kind != .eof {
		base_typ, storage := p.read_base_type()
		decls := p.read_type_extend(base_typ, storage, consume_comma: true)
		match p.tok.kind {
			.lsbr {
				if decls.len == 0 || decls[0].name == '' {
					p.token_err('Expected identifier')
				}
				if decls.len > 1 || decls[0].typ.decls.last() !is ast.Function {
					p.token_err('Expected `;` after top level declaration')
				}
				if decls[0].storage != .default {
					p.token_err('Illegal storage class specifier')
				}
				if decls[0].name in p.funs {
					p.token_err('function `${decls[0].name}` is already defined')
				}
				p.funs[decls[0].name] = p.function(decls[0].typ)
				p.globalscope.types[decls[0].name] = decls[0].typ
				p.globalscope.storages[decls[0].name] = decls[0].storage
			}
			.semi {
				for decl in decls {
					if decl.name in p.globalscope.types {
						p.token_err('global variable `$decl.name` is already declared')
					}
					p.globalscope.types[decl.name] = decl.typ
					p.globalscope.storages[decl.name] = decl.storage
				}
				p.next()
			}
			else {
				p.token_err('Expected `;` after top level declaration')
			}
		}
	}
	// println(p.funs)
}

fn (mut p Parser) function(typ ast.Type) ast.FunctionDecl {
	p.curscopes = []ast.ScopeTable{}
	func := typ.decls.last() as ast.Function
	body := p.block_stmt(args: func.args)
	p.curscope = -1
	return ast.FunctionDecl{
		typ: typ
		body: body
		scopes: p.curscopes
	}
}

[params]
struct BlockStmtParam {
	args []ast.FuncArgs
}

fn (mut p Parser) block_stmt(param BlockStmtParam) ast.BlockStmt {
	p.next()
	scopeid := p.curscopes.len
	parent_scopeid := p.curscope
	mut scope := ast.ScopeTable{
		parent: parent_scopeid
	}
	p.curscopes << scope
	p.curscope = scopeid
	for arg in param.args {
		p.curscopes[p.curscope].types[arg.name] = arg.typ
		p.curscopes[p.curscope].storages[arg.name] = .default
	}
	mut stmts := []ast.Stmt{}
	for p.tok.kind != .rsbr {
		if p.tok.kind == .eof {
			p.token_err('Expected `}`')
		}
		stmts << if p.tok.kind.is_type_keyword() { p.declaration() } else { p.stmt() } // TODO type def
	}
	p.next()
	p.curscope = parent_scopeid
	return ast.BlockStmt{
		stmts: stmts
		id: scopeid
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
			return p.block_stmt()
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
			if p.tok.kind.is_type_keyword() { // TODO definition
				base, storage := p.read_base_type()
				typ := p.read_type_extend(base, storage)[0]
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
			cond := p.ternary()
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
	base_typ, storage := p.read_base_type()
	mut inits := []ast.Decl{}
	for {
		// TODO storage class
		extend := p.read_type_extend(base_typ, storage)[0] or { break }
		if extend.name in p.curscopes[p.curscope].types {
			p.token_err('local variable `$extend.name` is already declared')
		}
		p.curscopes[p.curscope].types[extend.name] = extend.typ
		p.curscopes[p.curscope].storages[extend.name] = extend.storage
		if p.tok.kind == .assign {
			p.next()
			expr := p.expr()
			inits << ast.Decl{
				name: extend.name
				init: expr
			}
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
		decls: inits
	}
}
