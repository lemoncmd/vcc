module x8664

import ast
import strings

pub struct Gen {
	funs map[string]ast.FunctionDecl
mut:
	globalscope ast.ScopeTable
	curfn_name  string
	curfn_scope []ast.ScopeTable
	curscope    int = -1
	labelid int
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

pub fn (mut g Gen) get_label() int {
	g.labelid++
	return g.labelid
}

pub fn (mut g Gen) gen() {
	g.out = strings.new_builder(10000)
	g.writeln('.intel_syntax noprefix')
	g.writeln('.data')
	for name, typ in g.globalscope.types {
		if typ.decls.len != 0 && typ.decls.last() is ast.Function {
			continue
		}
		storage := g.globalscope.storages[name]
		if storage != .@static {
			g.writeln('.global $name')
		}
		g.writeln('$name:')
		g.writeln('.zero 8')
	}
	g.writeln('.text')
	for name, func in g.funs {
		g.curfn_name = name
		g.curfn_scope = func.scopes
		g.curscope = -1
		offset := g.set_fn_offset()
		// TODO static
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
		ast.IfStmt {
			label := g.get_label()
			has_else := stmt.else_stmt !is ast.EmptyStmt
			g.gen_expr(stmt.cond)
			g.writeln('  test rax, rax')
			if has_else {
				g.writeln('  je .L.ifelse.$label')
			} else {
				g.writeln('  je .L.ifend.$label')
			}
			g.gen_stmt(stmt.stmt)
			if has_else {
				g.writeln('  jmp .L.ifend.$label')
				g.writeln('.L.ifelse.$label:')
				g.gen_stmt(stmt.else_stmt)
			}
			g.writeln('.L.ifend.$label:')
		}
		ast.ForStmt {
			label := g.get_label()
			match stmt.first {
				ast.DeclStmt {}
				ast.ExprStmt {
					g.gen_expr(stmt.first.expr)
				}
				else {}
			}
			g.writeln('  jmp .L.forcond.$label')
			g.writeln('.L.forstmt.$label:')
			g.gen_stmt(stmt.stmt)
			g.gen_expr(stmt.next)
			g.writeln('.L.forcond.$label:')
			g.gen_expr(stmt.cond)
			g.writeln('  test rax, rax')
			g.writeln('  jne .L.forstmt.$label')
		}
		ast.WhileStmt {
			label := g.get_label()
			g.writeln('.L.whilecond.$label:')
			g.gen_expr(stmt.cond)
			g.writeln('  test rax, rax')
			g.writeln('  je .L.whileend.$label')
			g.gen_stmt(stmt.stmt)
			g.writeln('  jmp .L.whilecond.$label')
			g.writeln('.L.whileend.$label:')
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
	match expr {
		ast.LvarLiteral {
			_, _, offset := g.find_lvar(expr.name)
			g.writeln('  lea rax, [rbp - $offset]')
		}
		ast.GvarLiteral {
			g.writeln('  lea rax, $expr.name[rip]')
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
		ast.CallExpr {
			g.gen_lval(expr.left)
			g.writeln('  mov rdx, rax')
			g.writeln('  mov rax, 0')
			g.writeln('  call rdx')
		}
		ast.IntegerLiteral {
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
		ast.GvarLiteral {
			g.writeln('  mov rax, $expr.name[rip]')
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
			g.gen_lval(expr.left)
			g.writeln('  push rax')
			g.gen_expr(expr.right)
			g.writeln('  pop rdx')
			g.writeln('  mov qword ptr [rdx], rax')
		}
		else {}
	}
}
