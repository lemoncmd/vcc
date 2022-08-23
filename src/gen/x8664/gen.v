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
	labelid     int
	strings     []string
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
		frame_size := g.set_fn_offset()
		// TODO static
		g.writeln('.global $name')
		g.writeln('$name:')

		g.writeln('  push rbp')
		g.writeln('  mov rbp, rsp')
		g.writeln('  sub rsp, $frame_size')

		typ := func.typ.decls.last() as ast.Function
		reglen := if typ.args.len > 6 { 6 } else { typ.args.len }
		g.curscope = 0
		for i in 0 .. reglen {
			lvar_typ, _, offset := g.find_lvar(typ.args[i].name)
			if (lvar_typ.decls.len == 0 && lvar_typ.base is ast.Numerical)
				|| (lvar_typ.decls.len != 0 && lvar_typ.decls.last() is ast.Pointer) {
				size := get_type_size(lvar_typ)
				g.writeln('  mov ${get_size_str(size)} ptr [rbp - $offset], ${get_register(regs[i],
					size)}')
			}
		}
		g.curscope = -1

		g.gen_stmt(func.body)

		g.writeln('.L.return.$name:')
		g.writeln('  mov rsp, rbp')
		g.writeln('  pop rbp')
		g.writeln('  ret')
	}
	g.writeln('.data')
	for i, str in g.strings {
		g.writeln('.L.string.$i:')
		g.writeln('  .string "$str"')
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
		ast.DeclStmt {
			for decl in stmt.decls {
				expr := decl.init as ast.Expr
				g.gen_expr(expr)
				typ, _, offset := g.find_lvar(decl.name)
				g.writeln('  lea rdx, [rbp - $offset]')
				size := get_type_size(typ)
				g.writeln('  mov ${get_size_str(size)} ptr [rdx], ${get_register(.rax,
					size)}')
			}
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

fn (mut g Gen) gen_lval(expr ast.Expr) ast.Type {
	match expr {
		ast.LvarLiteral {
			typ, _, offset := g.find_lvar(expr.name)
			g.writeln('  lea rax, [rbp - $offset]')
			return typ
		}
		ast.GvarLiteral {
			g.writeln('  mov rax, OFFSET FLAT:$expr.name')
			return if typ := g.globalscope.types[expr.name] {
				typ
			} else {
				ast.Type{
					base: ast.Numerical.int
				}
			}
		}
		ast.DerefExpr {
			g.gen_expr(expr.left)
			return expr.typ
		}
		else {}
	}
	return ast.Type{
		base: ast.Numerical.int
	}
}

fn (mut g Gen) gen_load(dst Register, src string, typ ast.Type) {
	if typ.decls.len != 0 && typ.decls.last() is ast.Pointer {
		g.writeln('  mov $dst, qword ptr [$src]')
	}
	if typ.decls.len == 0 {
		if typ.base is ast.Numerical {
			instruction := match typ.base {
				.char, .schar, .short { 'movsx' }
				.uchar, .ushort { 'movzx' }
				.int { 'movsxd' }
				.uint, .long, .longlong, .ulong, .ulonglong { 'mov' }
				else { 'INVALID' }
			}
			dst_str := get_register(dst, if typ.base in [.uint, .ulong] { 4 } else { 8 })
			size := get_size_str(get_type_size(typ))
			g.writeln('  $instruction $dst_str, $size ptr [$src]')
		}
	}
}

pub fn (mut g Gen) gen_expr(expr ast.Expr) {
	match expr {
		ast.CrementExpr {
			typ := g.gen_lval(expr.left)
			if !expr.is_front {
				g.gen_load(.rdx, 'rax', typ)
			}
			size := get_size_str(get_type_size(typ))
			incr := if typ.decls.len == 0 {
				1
			} else {
				get_pointer_type_size(typ)
			}
			g.writeln(if expr.op == .plus {
				'  add $size ptr [rax], $incr'
			} else {
				'  sub $size ptr [rax], $incr'
			})
			if expr.is_front {
				g.gen_load(.rax, 'rax', typ)
			} else {
				g.writeln('  mov rax, rdx')
			}
		}
		ast.CallExpr {
			for arg in expr.args.reverse() {
				g.gen_expr(arg)
				g.writeln('  push rax')
			}
			g.gen_lval(expr.left)
			g.writeln('  mov rbx, rax')
			g.writeln('  mov rax, 0')
			reglen := if expr.args.len > 6 { 6 } else { expr.args.len }
			for i in 0 .. reglen {
				g.writeln('  pop ${regs[i]}')
			}
			g.writeln('  call rbx')
		}
		ast.IntegerLiteral {
			g.writeln('  mov rax, $expr.val')
		}
		ast.StringLiteral {
			g.writeln('  mov rax, OFFSET FLAT:.L.string.$g.strings.len')
			g.strings << expr.val
		}
		ast.BinaryExpr {
			g.gen_binary(expr)
		}
		ast.UnaryExpr {
			g.gen_unary(expr)
		}
		ast.DerefExpr {
			g.gen_expr(expr.left)
			g.gen_load(.rax, 'rax', expr.typ)
		}
		ast.LvarLiteral {
			typ, _, offset := g.find_lvar(expr.name)
			g.gen_load(.rax, 'rbp - $offset', typ)
		}
		ast.GvarLiteral {
			typ := if typ_ := g.globalscope.types[expr.name] {
				typ_
			} else {
				ast.Type{
					base: ast.Numerical.int
				}
			}
			g.gen_load(.rax, '$expr.name', typ)
		}
		ast.SizeofExpr {
			typ := expr as ast.Type
			size := get_type_size(typ)
			eprintln(typ)
			g.writeln('  mov rax, $size')
		}
		ast.TernaryExpr {
			label := g.get_label()
			g.gen_expr(expr.cond)
			g.writeln('  test rax, rax')
			g.writeln('  je .L.ifelse.$label')
			g.gen_expr(expr.left)
			g.writeln('  jmp .L.ifend.$label')
			g.writeln('.L.ifelse.$label:')
			g.gen_expr(expr.right)
			g.writeln('.L.ifend.$label:')
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
		.aand {
			g.gen_lval(expr.left)
		}
		.lnot {
			g.gen_expr(expr.left)
			g.writeln('  cmp rax, 0')
			g.writeln('  sete al')
			g.writeln('  movzx eax, al')
		}
		.anot {
			g.gen_expr(expr.left)
			g.writeln('  not rax')
		}
		else {}
	}
}

// TODO unsigned
pub fn (mut g Gen) gen_binary(expr ast.BinaryExpr) {
	if expr.op in [.plus, .minus, .mul, .div, .mod, .aand, .aor, .xor, .eq, .ne, .gt, .ge, .lt,
		.le] {
		g.gen_expr(expr.right)
		g.writeln('  push rax')
		g.gen_expr(expr.left)
		g.writeln('  pop rdx')
	}
	typ, size := if expr.op.is_assign() {
		typ := g.gen_lval(expr.left)
		g.writeln('  push rax')
		g.gen_expr(expr.right)
		g.writeln('  pop ' + if expr.op in [.ls_assign, .rs_assign] { 'rcx' } else {'rdx'})
		typ, get_type_size(typ)
	} else { ast.Type{base: ast.Void{}}, 0 }
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
		.aand {
			g.writeln('  and rax, rdx')
		}
		.aor {
			g.writeln('  or rax, rdx')
		}
		.xor {
			g.writeln('  xor rax, rdx')
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
		.comma {
			g.gen_expr(expr.left)
			g.gen_expr(expr.right)
		}
		.lshift {
			g.gen_expr(expr.right)
			g.writeln('  push rax')
			g.gen_expr(expr.left)
			g.writeln('  pop rcx')
			g.writeln('  shl rax, cl')
		}
		.rshift {
			g.gen_expr(expr.right)
			g.writeln('  push rax')
			g.gen_expr(expr.left)
			g.writeln('  pop rcx')
			g.writeln('  sar rax, cl')
		}
		.land {
			label := g.get_label()
			g.gen_expr(expr.left)
			g.writeln('  test rax, rax')
			g.writeln('  je .L.andfalse.$label')
			g.gen_expr(expr.right)
			g.writeln('  test rax, rax')
			g.writeln('  je .L.andfalse.$label')
			g.writeln('  mov rax, 1')
			g.writeln('  jmp .L.andend.$label')
			g.writeln('.L.andfalse.$label:')
			g.writeln('  mov rax, 0')
			g.writeln('.L.andend.$label:')
		}
		.lor {
			label := g.get_label()
			g.gen_expr(expr.left)
			g.writeln('  test rax, rax')
			g.writeln('  jne .L.ortrue.$label')
			g.gen_expr(expr.right)
			g.writeln('  test rax, rax')
			g.writeln('  jne .L.ortrue.$label')
			g.writeln('  mov rax, 0')
			g.writeln('  jmp .L.orend.$label')
			g.writeln('.L.ortrue.$label:')
			g.writeln('  mov rax, 1')
			g.writeln('.L.orend.$label:')
		}
		.assign {
			g.writeln('  mov ${get_size_str(size)} ptr [rdx], ${get_register(.rax, size)}')
		}
		.pl_assign {
			g.writeln('  add ${get_size_str(size)} ptr [rdx], ${get_register(.rax, size)}')
			g.gen_load(.rax, 'rdx', typ)
		}
		.mn_assign {
			g.writeln('  sub ${get_size_str(size)} ptr [rdx], ${get_register(.rax, size)}')
			g.gen_load(.rax, 'rdx', typ)
		}
		.ml_assign {
			g.writeln('  imul ${get_size_str(size)} ptr [rdx], ${get_register(.rax, size)}')
			g.gen_load(.rax, 'rdx', typ)
		}
		// TODO
		.dv_assign {
			g.writeln('  add ${get_size_str(size)} ptr [rdx], ${get_register(.rax, size)}')
			g.gen_load(.rax, 'rdx', typ)
		}
		// TODO
		.md_assign {
			g.writeln('  add ${get_size_str(size)} ptr [rdx], ${get_register(.rax, size)}')
			g.gen_load(.rax, 'rdx', typ)
		}
		.an_assign {
			g.writeln('  and ${get_size_str(size)} ptr [rdx], ${get_register(.rax, size)}')
			g.gen_load(.rax, 'rdx', typ)
		}
		.or_assign {
			g.writeln('  or ${get_size_str(size)} ptr [rdx], ${get_register(.rax, size)}')
			g.gen_load(.rax, 'rdx', typ)
		}
		.xo_assign {
			g.writeln('  xor ${get_size_str(size)} ptr [rdx], ${get_register(.rax, size)}')
			g.gen_load(.rax, 'rdx', typ)
		}
		.ls_assign {
			g.writeln('  add ${get_size_str(size)} ptr [rdx], cl')
			g.gen_load(.rax, 'rdx', typ)
		}
		.rs_assign {
			g.writeln('  add ${get_size_str(size)} ptr [rdx], cl')
			g.gen_load(.rax, 'rdx', typ)
		}
		else {}
	}
}
