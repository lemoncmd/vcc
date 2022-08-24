module checker

import ast

pub struct Checker {
	globalscope ast.ScopeTable
mut:
	curfn_scope []ast.ScopeTable
	curscope    int = -1
pub mut:
	funs map[string]ast.FunctionDecl
}

pub fn (mut c Checker) top() {
	for _, mut func in c.funs {
		c.curfn_scope = func.scopes
		c.curscope = -1
		c.stmt(mut func.body)
	}
}

fn (mut c Checker) stmt(mut stmt ast.Stmt) {
	match stmt {
		ast.BlockStmt {
			mut stmt_ := stmt as ast.BlockStmt
			parent := c.curscope
			c.curscope = stmt_.id
			for mut content_stmt in stmt_.stmts {
				c.stmt(mut content_stmt)
			}
			c.curscope = parent
			stmt = stmt_
		}
		ast.BreakStmt {}
		ast.CaseStmt {}
		ast.ContinueStmt {}
		ast.DeclStmt {
			mut stmt_ := stmt as ast.DeclStmt
			for mut decl in stmt_.decls {
				c.init(mut decl.init)
			}
			stmt = stmt_
		}
		ast.DefaultStmt {}
		ast.DoStmt {
			mut stmt_ := stmt as ast.DoStmt
			c.expr(mut stmt_.cond)
			c.stmt(mut stmt_.stmt)
			stmt = stmt_
		}
		ast.EmptyStmt {}
		ast.ExprStmt {
			mut stmt_ := stmt as ast.ExprStmt
			c.expr(mut stmt_.expr)
			stmt = stmt_
		}
		ast.ForStmt {
			mut stmt_ := stmt as ast.ForStmt
			parent := c.curscope
			c.curscope = stmt_.id
			c.stmt(mut stmt_.first)
			c.expr(mut stmt_.cond)
			c.expr(mut stmt_.next)
			c.stmt(mut stmt_.stmt)
			c.curscope = parent
			stmt = stmt_
		}
		ast.GotoStmt {}
		ast.IfStmt {
			mut stmt_ := stmt as ast.IfStmt
			c.expr(mut stmt_.cond)
			c.stmt(mut stmt_.stmt)
			c.stmt(mut stmt_.else_stmt)
			stmt = stmt_
		}
		ast.LabelStmt {}
		ast.ReturnStmt {
			mut stmt_ := stmt as ast.ReturnStmt
			c.expr(mut stmt_.expr)
			stmt = stmt_
		}
		ast.SwitchStmt {}
		ast.WhileStmt {
			mut stmt_ := stmt as ast.WhileStmt
			c.expr(mut stmt_.cond)
			c.stmt(mut stmt_.stmt)
			stmt = stmt_
		}
	}
}

fn (mut c Checker) init(mut init ast.Init) {
	match init {
		ast.Expr {
			mut expr := init as ast.Expr
			c.expr(mut expr)
			init = expr
		}
		[]ast.Init {
			for mut i_ in init as []ast.Init {
				mut i := i_
				c.init(mut i)
				i_ = i
			}
		}
	}
}

fn (mut c Checker) expr(mut expr ast.Expr) ast.Type {
	match expr {
		ast.BinaryExpr {
			mut expr_ := expr as ast.BinaryExpr
			typ := c.binary(mut expr_)
			expr = expr_
			return typ
		}
		ast.CallExpr {
			mut expr_ := expr as ast.CallExpr
			mut typ := c.expr(mut expr_.left)
			expr = expr_
			typ.decls.pop()
			return typ
		}
		ast.CastExpr {
			mut expr_ := expr as ast.CastExpr
			c.expr(mut expr_.left)
			expr = expr_
			mut typ := expr_.typ
			typ.decls = typ.decls.clone()
			return typ
		}
		ast.CrementExpr {
			mut expr_ := expr as ast.CrementExpr
			typ := c.expr(mut expr_.left)
			expr = expr_
			return typ
		}
		ast.FloatLiteral {
			return ast.Type{
				base: ast.Numerical.float
			}
		}
		ast.GvarLiteral {
			name := (expr as ast.GvarLiteral).name
			mut typ := c.globalscope.types[name] or {
				panic('Global variable $name not found')
			}
			typ.decls = typ.decls.clone()
			return typ
		}
		ast.IntegerLiteral {
			return ast.Type{
				base: ast.Numerical.int
			}
		}
		ast.LvarLiteral {
			mut scopeid := c.curscope
			name := (expr as ast.LvarLiteral).name
			for scopeid != -1 {
				scope := c.curfn_scope[scopeid]
				if mut typ := scope.types[name] {
					typ.decls = typ.decls.clone()
					return typ
				}
				scopeid = scope.parent
			}
			panic('Local variable $name not found')
		}
		ast.SelectorExpr {
			return ast.Type{
				base: ast.Numerical.int // TODO
			}
		}
		ast.SizeofExpr {
			mut expr_ := expr as ast.SizeofExpr
			if expr_ is ast.Expr {
				mut expr__ := expr_ as ast.Expr
				typ := c.expr(mut expr__)
				expr = ast.SizeofExpr(typ)
			}
			return ast.Type{
				base: ast.Numerical.ulonglong
			}
		}
		ast.StringLiteral {
			s := expr as ast.StringLiteral
			return ast.Type{
				base: ast.Numerical.char
				decls: [ast.Declarator(ast.Array{
					number: s.val.len
				})] // TODO invalid char and escape seq. change to []u8
			}
		}
		ast.TernaryExpr {
			mut expr_ := expr as ast.TernaryExpr
			c.expr(mut expr_.cond) // TODO check if it is numerical
			lhs := c.expr(mut expr_.left)
			rhs := c.expr(mut expr_.right)
			expr = expr_
			return extend(lhs, rhs) // TODO
		}
		ast.UnaryExpr {
			mut expr_ := expr as ast.UnaryExpr
			typ := c.unary(mut expr_)
			expr = expr_
			return typ
		}
		ast.DerefExpr {
			mut expr_ := expr as ast.DerefExpr
			mut typ := c.expr(mut expr_.left)
			if typ.decls.len == 0 || typ.decls.last() is ast.Function {
				panic('Cannot dereference type which is not a pointer')
			}
			typ.decls = typ.decls.clone()
			expr_.decl = typ.decls.pop()
			expr_.typ = typ
			expr = expr_
			return typ
		}
		ast.GenericExpr {
			// TODO
		}
	}
	return ast.Type{
		base: ast.Numerical.int
	}
}

fn extend(lhs ast.Type, rhs ast.Type) ast.Type {
	if lhs.decls.len != 0 || rhs.decls.len != 0 || lhs.base !is ast.Numerical
		|| rhs.base !is ast.Numerical {
			panic('Internal type error\nlhs:\n$lhs\nrhs:\n$rhs')
	}
	lhs_num := lhs.base as ast.Numerical
	rhs_num := rhs.base as ast.Numerical
	lhs_extended := if int(lhs_num) < int(ast.Numerical.int) { ast.Numerical.int } else { lhs_num }
	rhs_extended := if int(rhs_num) < int(ast.Numerical.int) { ast.Numerical.int } else { rhs_num }
	if lhs_extended == rhs_extended {
		return ast.Type{
			base: lhs_extended
		}
	}
	return ast.Type{
		base: if int(lhs_extended) < int(rhs_extended) { rhs_extended } else { lhs_extended }
	}
}

fn (mut c Checker) binary(mut expr ast.BinaryExpr) ast.Type {
	mut lhs := c.expr(mut expr.left)
	mut rhs := c.expr(mut expr.right)
	if expr.op == .comma {
		return rhs
	}
	if expr.op.is_assign() || expr.op in [.lshift, .rshift] {
		return lhs
	}
	if expr.op == .plus {
		if lhs.decls.len != 0 {
			mut sizeoftyp := lhs
			sizeoftyp.decls = sizeoftyp.decls.clone()
			sizeoftyp.decls.pop()
			expr.right = ast.BinaryExpr{
				op: .mul
				left: expr.right
				right: ast.SizeofExpr(sizeoftyp)
			}
			return lhs
		}
		if rhs.decls.len != 0 {
			mut sizeoftyp := rhs
			sizeoftyp.decls = sizeoftyp.decls.clone()
			sizeoftyp.decls.pop()
			expr.left = ast.BinaryExpr{
				op: .mul
				left: expr.left
				right: ast.SizeofExpr(sizeoftyp)
			}
			return rhs
		}
		return extend(lhs, rhs)
	}
	if expr.op == .minus {
		if lhs.decls.len != 0 && rhs.decls.len != 0 {
			// TODO
		}
		if lhs.decls.len != 0 {
			mut sizeoftyp := lhs
			sizeoftyp.decls = sizeoftyp.decls.clone()
			sizeoftyp.decls.pop()
			expr.right = ast.BinaryExpr{
				op: .mul
				left: expr.right
				right: ast.SizeofExpr(sizeoftyp)
			}
			return lhs
		}
		return extend(lhs, rhs)
	}
	if expr.op in [.mul, .div, .mod] {
		return extend(lhs, rhs)
	}
	return ast.Type{
		base: ast.Numerical.int
	}
}

fn (mut c Checker) unary(mut expr ast.UnaryExpr) ast.Type {
	mut typ := c.expr(mut expr.left)
	if expr.op == .lnot {
		return ast.Type{
			base: ast.Numerical.int
		}
	}
	if expr.op == .aand {
		typ.decls << ast.Pointer{}
		return typ
	}
	return extend(typ, ast.Type{ base: ast.Numerical.int })
}
