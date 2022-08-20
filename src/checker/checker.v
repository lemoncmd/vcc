module checker

import ast

struct Checker {
	globalscope ast.ScopeTable
mut:
	curfn_scope []ast.ScopeTable
	curscope    int = -1
pub mut:
	funs map[string]ast.FunctionDecl
}
fn (mut c Checker) top() {
	for name, func in c.funs {

	}
}

fn (mut c Checker) stmt(stmt ast.Stmt) {}
/*
fn (mut c Checker) expr(mut expr ast.Expr) ast.Type {
	return ast.Type{base:ast.Numerical.int}
}*/
fn (mut c Checker) expr(mut expr ast.Expr) ast.Type {
	return match expr {
		ast.BinaryExpr { c.binary(mut expr) }
//		ast.CallExpr {
//			mut typ := c.expr(mut expr.left)
//			typ.decls.pop()
//			typ
//		}
//		ast.CastExpr {
//			typ := expr.typ
//			typ.decls = typ.decls.clone()
//			typ
//		}
//		ast.CrementExpr {
//			c.expr(mut expr.left)
//		}
		ast.FloatLiteral {
			ast.Type {
				base: ast.Numerical.float
			}
		}
		ast.GvarLiteral {
			ast.Type {
				base: ast.Numerical.int  // TODO
			}
		}
		ast.IntegerLiteral {
			ast.Type {
				base: ast.Numerical.int
			}
		}
		ast.LvarLiteral {
			ast.Type {
				base: ast.Numerical.int  // TODO
			}
		}
		ast.SelectorExpr {
			ast.Type {
				base: ast.Numerical.int  // TODO
			}
		}
		ast.SizeofExpr {
			if expr is ast.Expr {
				typ := c.expr(mut expr)
				expr = ast.SizeofExpr(typ)
			}
			ast.Type {
				base: ast.Numerical.ulonglong
			}
		}
		ast.StringLiteral {
			ast.Type {
				base: ast.Numerical.char
				decls: [ast.Declarator(ast.Array{number: val.len})] // TODO invalid char and escape seq. change to []u8
			}
		}
//		ast.TernaryExpr {
//			c.expr(mut expr.cond) //TODO check if it is numerical
//			lhs := c.expr(mut expr.left)
//			rhs := c.expr(mut expr.right)
//			extend(lhs, rhs)// TODO
//		}
		ast.UnaryExpr { c.unary(mut expr) }
//		ast.DerefExpr {
//			mut typ := c.expr(mut expr.left)
//			if typ.decls.len == 0 || typ.decls.last() !is ast.Pointer {
//				panic('Cannot dereference type which is not a pointer')
//			}
//			typ.decls.pop()
//			expr.typ = typ
//			typ
//		}
		else { ast.Type{base: ast.Numerical.int} }
	}
}


fn extend(lhs ast.Type, rhs ast.Type) ast.Type {
	if lhs.decls.len != 0 || rhs.decls.len != 0 || lhs.base !is ast.Numerical || rhs.base !is ast.Numerical {
		panic('Internal type error')
	}
	lhs_num := lhs.base as ast.Numerical
	rhs_num := rhs.base as ast.Numerical
	lhs_extended := if int(lhs_num) < int(ast.Numerical.int) { ast.Numerical.int } else { lhs_num }
	rhs_extended := if int(rhs_num) < int(ast.Numerical.int) { ast.Numerical.int } else { rhs_num }
	if lhs_extended == rhs_extended {
		return ast.Type{base: lhs_extended}
	}
	return ast.Type{base: if int(lhs_extended) < int(rhs_extended) { rhs_extended } else {lhs_extended}}
}
fn (mut c Checker) binary(mut expr ast.BinaryExpr) ast.Type {
	lhs := c.expr(mut expr.left)
	rhs := c.expr(mut expr.right)
	if expr.op == .comma {
		return rhs
	}
	if expr.op.is_assign() || expr.op in [.lshift, .rshift] {
		return lhs
	}
	if expr.op in [.plus, .minus, .mul, .div, .mod] {
		return extend(lhs, rhs)
	}
	return ast.Type{base: ast.Numerical.int}
}

fn (mut c Checker) unary(mut expr ast.UnaryExpr) ast.Type {
	mut typ := c.expr(mut expr.left)
	if expr.op == .lnot {
		return ast.Type{base: ast.Numerical.int}
	}
	if expr.op == .aand {
		typ.decls << ast.Pointer{}
		return typ
	}
	return extend(typ, ast.Type{base: ast.Numerical.int})
}
