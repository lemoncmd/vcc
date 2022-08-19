module x8664

import ast
import strings

pub struct Gen {
	funs map[string]ast.FunctionDecl
mut:
	curfn_name string
	curfn_scope []ast.ScopeTable
	curscope int = -1
pub mut:
	out strings.Builder
}

pub fn (mut g Gen) writeln(s string) {
	g.out.writeln(s)
}

pub fn (g Gen) find_lvar(name string) (ast.Type, ast.Storage, int) {
	mut scopeid := g.curscope
	for scopeid != -1 {
		scope := g.curfn_scope[scopeid]
		if name in scope.types {
			return scope.types[name], scope.storages[name], scope.offset[name]
		}
		scopeid = scope.parent
	}
	panic('Cannot find lvar in gen')
}

pub fn (mut g Gen) gen() {
	g.out = strings.new_builder(10000)
	g.writeln('.intel_syntax noprefix')
	g.writeln('.data')
	g.writeln('.text')
	for name, func in g.funs {
		g.curfn_name = name
		g.curfn_scope = func.scopes
		g.curscope = -1
		offset := g.set_fn_offset()
		g.writeln('.global $name')
		g.writeln('$name:')

		g.writeln('  push rbp')
		g.writeln('  mov rbp, rsp')
		g.writeln('  sub rsp, $offset')

		g.gen_stmt(func.body)

		g.writeln('.L.return.$name:')
		g.writeln('  mov rsp, rbp')
		g.writeln('  pop rbp')
		g.writeln('  ret')
	}
}

pub fn (mut g Gen) gen_stmt(stmt ast.Stmt) {
	match stmt {
		ast.BlockStmt {
			parent := g.curscope
			g.curscope = stmt.id
			for s in stmt.stmts {
				g.gen_stmt(s)
			}
			g.curscope = parent
		}
		ast.ForStmt {
			match stmt.first {
				ast.DeclStmt {}
				ast.ExprStmt {
					g.gen_expr(stmt.first.expr)
				}
				else {}
			}
			g.gen_stmt(stmt.stmt)
			g.gen_expr(stmt.next)
			g.gen_expr(stmt.cond)
		}
		ast.ExprStmt {
			g.gen_expr(stmt.expr)
		}
		ast.ReturnStmt {
			g.gen_expr(stmt.expr)
			g.writeln('  jmp .L.return.$g.curfn_name')
		}
		else {}
	}
}

fn (mut g Gen) gen_lval(expr ast.Expr) {
	println(expr)
	match expr {
		ast.LvarLiteral {
			_, _, offset := g.find_lvar(expr.name)
			g.writeln('  lea rax, [rbp - $offset]')
		}
		else {}
	}
}

pub fn (mut g Gen) gen_expr(expr ast.Expr) {
	match expr {
		ast.CrementExpr {
			g.gen_lval(expr.left)
			if !expr.is_front {
				g.writeln('  mov rdx, qword ptr [rax]')
			}
			g.writeln(if expr.op == .plus {
				'  add qword ptr [rax], 1'
			} else {
				'  sub qword ptr [rax], 1'
			})
			if expr.is_front {
				g.writeln('  mov rax, qword ptr [rax]')
			} else {
				g.writeln('  mov rax, rdx')
			}
		}
		ast.CallExpr {}
		ast.IntegerLiteral{
			g.writeln('  mov rax, $expr.val')
		}
		ast.BinaryExpr {
			g.gen_binary(expr)
		}
		ast.UnaryExpr {
			g.gen_unary(expr)
		}
		ast.LvarLiteral {
			_, _, offset := g.find_lvar(expr.name)
			g.writeln('  mov rax, [rbp - $offset]')
		}
		else {}
	}
}

pub fn (mut g Gen) gen_unary(expr ast.UnaryExpr) {
	match expr.op {
		.plus {
			g.gen_expr(expr.left)
		}
		.minus {
			g.gen_expr(expr.left)
			g.writeln('  neg rax')
		}
		else {}
	}
}

pub fn (mut g Gen) gen_binary(expr ast.BinaryExpr) {
	if expr.op in [.plus, .minus, .mul, .div, .mod, .eq, .ne, .gt, .ge, .lt, .le] {
		g.gen_expr(expr.right)
		g.writeln('  push rax')
		g.gen_expr(expr.left)
		g.writeln('  pop rdx')
	}
	match expr.op {
		.plus {
			g.writeln('  add rax, rdx')
		}
		.minus {
			g.writeln('  sub rax, rdx')
		}
		.mul {
			g.writeln('  imul rax, rdx')
		}
		.div {
			g.writeln('  mov rcx, rdx')
			g.writeln('  cqo')
			g.writeln('  idiv rcx')
		}
		.mod {
			g.writeln('  mov rcx, rdx')
			g.writeln('  cqo')
			g.writeln('  idiv rcx')
			g.writeln('  mov rax, rdx')
		}
		.eq, .ne, .gt, .ge, .lt, .le {
			cmd := match expr.op {
				.eq { 'e' }
				.ne { 'ne' }
				.gt { 'g' }
				.ge { 'ge' }
				.lt { 'l' }
				.le { 'le' }
				else { '' }
			}
			g.writeln('  cmp rax, rdx')
			g.writeln('  set$cmd al')
			g.writeln('  movzx eax, al')
		}
		.assign {
			g.gen_expr(expr.right)
			g.writeln('  push rax')
			g.gen_lval(expr.left)
			g.writeln('  pop rdx')
			g.writeln('  mov qword ptr [rax], rdx')
		}
		else {}
	}
}
