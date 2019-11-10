module main

const (
  Regs = ['rdi', 'rsi', 'rdx', 'rcx', 'r8', 'r9']
  Reg4 = ['edi', 'esi', 'edx', 'ecx', 'r8d', 'r9d']
)

fn (p mut Parser) gen_main() {
  println('.intel_syntax noprefix')
  println('.data')

  for name, _gvar in p.global {
    gvar := _gvar.val
    size := gvar.typ.size()
    if !gvar.is_static {
      println('.global $name')
    }
    println('$name:')
    println('  .zero $size')
  }

  for i, _node in p.strs {
    node := _node.val
    offset := node.offset
    content := node.name
    println('.L.C.$offset:')
    println('  .string "$content"')
  }

  println('.text')

  for name, _func in p.code {
    func := _func.val
    p.curfn = func
    offset := align(p.curfn.offset, 16)

    if !func.is_static {
      println('.global $name')
    }
    println('$name:')
    println('  push rbp')
    println('  mov rbp, rsp')
    println('  sub rsp, $offset')

    mut fnargs := func.args
    for i := 0; i < func.num; i++ {
      reg := match fnargs.left.typ.size() {
        4 {Reg4[i]}
        8 {Regs[i]}
        else {'none'}
      }
      if reg == 'none' {
        parse_err('Invalid type in arg of function $name')
      }
      println('  mov [rbp-${fnargs.left.offset}], $reg')
      fnargs = fnargs.right
    }

    p.gen(func.content)

    println('.L.return.$name:')
    println('  mov rsp, rbp')
    println('  pop rbp')
    println('  ret')
  }
}

fn (p mut Parser) gen_lval(node &Node) {
  if node.kind != .lvar && node.kind != .deref {
    parse_err('Assignment Error: left value is invalid')
  }

  if node.kind == .deref {
    p.gen(node.left)
    return
  }

  println('  mov rax, rbp')
  println('  sub rax, ${node.offset}')
  println('  push rax')
}

fn (p mut Parser) gen_gval(node &Node) {
  if node.kind != .gvar && node.kind != .deref {
    parse_err('Assignment Error: left value is invalid')
  }

  if node.kind == .deref {
    p.gen(node.left)
    return
  }

  println('  push offset ${node.name}')
}

fn (p Parser) gen_inc(kind Nodekind, typ &Type){
  println('  pop rax')
  if typ.kind.last() == .ary {
    parse_err('you cannot inc/decrement array')
  }
  cmd := if kind in [.incb, .incf] {
    'add'
  } else {
    'sub'
  }
  if kind in [.incb, .decb] {
    match typ.size() {
      1 {println('  movsx rdx, byte ptr [rax]')}
      2 {println('  movsx rdx, word ptr [rax]')}
      4 {println('  movsxd rdx, dword ptr [rax]')}
      8 {println('  mov rdx, [rax]')}
      else {parse_err('you are loading something wrong')}
    }
    println('  push rdx')
  }
  if typ.kind.last() != .ptr {
    match typ.size() {
      1 {println('  $cmd byte ptr [rax], 1')}
      2 {println('  $cmd word ptr [rax], 1')}
      4 {println('  $cmd dword ptr [rax], 1')}
      8 {println('  $cmd [rax], 1')}
      else {parse_err('you are loading something wrong')}
    }
  } else {
    size := typ.reduce().size()
    println('  $cmd [rax], $size')
  }
  if kind in [.incf, .decf] {
    match typ.size() {
      1 {println('  movsx rdx, byte ptr [rax]')}
      2 {println('  movsx rdx, word ptr [rax]')}
      4 {println('  movsxd rdx, dword ptr [rax]')}
      8 {println('  mov rdx, [rax]')}
      else {parse_err('you are loading something wrong')}
    }
    println('  push rdx')
  }
}

fn (p Parser) gen_load(typ &Type){
  println('  pop rax')
  match typ.size() {
    1 {println('  movsx rax, byte ptr [rax]')}
    2 {println('  movsx rax, word ptr [rax]')}
    4 {println('  movsxd rax, dword ptr [rax]')}
    8 {println('  mov rax, [rax]')}
    else {parse_err('you are loading something wrong')}
  }
  println('  push rax')
}

fn (p Parser) gen_store(typ &Type){
  println('  pop rdi')
  println('  pop rax')
  match typ.size() {
    1 {println('  mov [rax], dil')}
    2 {println('  mov [rax], di')}
    4 {println('  mov [rax], edi')}
    8 {println('  mov [rax], rdi')}
    else {parse_err('you are saving something wrong')}
  }
  println('  push rdi')
}

fn (p mut Parser) gen(node &Node) {
  match node.kind {
    .ret {
      p.gen(node.left)
      println('  pop rax')
      println('  jmp .L.return.${p.curfn.name}')
      return
    }
    .addr {
      if node.left.kind == .lvar {
        p.gen_lval(node.left)
      } else {
        p.gen_gval(node.left)
      }
      return
    }
    .deref {
      p.gen(node.left)
      if node.typ.kind.last() != .ary {
        p.gen_load(node.typ)
      }
      return
    }
    .incb, .decb, .incf, .decf {
      if node.left.kind == .lvar {
        p.gen_lval(node.left)
      } else {
        p.gen_gval(node.left)
      }
      p.gen_inc(node.kind, node.left.typ)
      return
    }
    .block {
      for i in node.code {
        code := &Node(i)
        p.gen(code)
      }
      return
    }
    .ifn {
      p.gen(node.cond)
      println('  pop rax')
      println('  cmp rax, 0')
      println('  je .L.end.${node.num}')
      p.gen(node.left)
      println('.L.end.${node.num}:')
      return
    }
    .ifelse {
      p.gen(node.cond)
      println('  pop rax')
      println('  cmp rax, 0')
      println('  je .L.else.${node.num}')
      p.gen(node.left)
      println('  jmp .L.end.${node.num}')
      println('.L.else.${node.num}:')
      p.gen(node.right)
      println('.L.end.${node.num}:')
      return
    }
    .forn {
      p.gen(node.first)
      println('.L.begin.${node.num}:')
      p.gen(node.cond)
      println('  pop rax')
      println('  cmp rax, 0')
      println('  je .L.end.${node.num}')
      p.genifnum << node.num
      p.gen(node.left)
      p.genifnum.delete(p.genifnum.len-1)
      println('.L.cont.${node.num}:')
      p.gen(node.right)
      println('  jmp .L.begin.${node.num}')
      println('.L.end.${node.num}:')
      return
    }
    .while {
      println('.L.begin.${node.num}:')
      p.gen(node.cond)
      println('  pop rax')
      println('  cmp rax, 0')
      println('  je .L.end.${node.num}')
      p.genifnum << node.num
      p.gen(node.left)
      p.genifnum.delete(p.genifnum.len-1)
      println('.L.cont.${node.num}:')
      println('  jmp .L.begin.${node.num}')
      println('.L.end.${node.num}:')
      return
    }
    .do {
      println('.L.begin.${node.num}:')
      p.genifnum << node.num
      p.gen(node.left)
      p.genifnum.delete(p.genifnum.len-1)
      println('.L.cont.${node.num}:')
      p.gen(node.cond)
      println('  pop rax')
      println('  cmp rax, 0')
      println('  je .L.end.${node.num}')
      println('  jmp .L.begin.${node.num}')
      println('.L.end.${node.num}:')
      return
    }
    .brk {
      if p.genifnum.len == 0 {
        parse_err('cannot break not in loop statement')
      }
      ifnum := p.genifnum.last()
      println('  jmp .L.end.$ifnum')
      return
    }
    .cont {
      if p.genifnum.len == 0 {
        parse_err('cannot continue not in loop statement')
      }
      ifnum := p.genifnum.last()
      println('  jmp .L.cont.$ifnum')
      return
    }
    .label {
      println('.L.label.${node.name}:')
      p.gen(node.left)
      return
    }
    .gozu {
      if !(node.name in p.curfn.labels) {
        parse_err('${node.name} used in goto but not declared')
      }
      println('  jmp .L.label.${node.name}')
      return
    }
    .num {
      println('  push ${node.num}')
      return
    }
    .string {
      println('  push offset .L.C.${node.offset}')
      return
    }
    .lvar {
      p.gen_lval(node)
      if node.typ.kind.last() != .ary {
        p.gen_load(node.typ)
      }
      return
    }
    .gvar {
      p.gen_gval(node)
      if node.typ.kind.last() != .ary {
        p.gen_load(node.typ)
      }
      return
    }
    .assign {
      if node.left.typ.kind.last() == .ary {
        parse_err('Assignment Error: array body is not assignable')
      }
      if node.left.kind == .lvar {
        p.gen_lval(node.left)
      } else {
        p.gen_gval(node.left)
      }
      p.gen(node.right)
      p.gen_store(node.typ)
      return
    }
    .call {
      mut args := node.left
      for i in [0].repeat(node.num) {
        p.gen(args.left)
        args = args.right
      }
      for i in Regs.left(node.num).reverse() {
        println('  pop $i')
      }
      println('  mov rax, rsp')
      println('  and rax, 15')
      println('  jnz .L.call.${p.ifnum}')
      println('  mov rax, 0')
      println('  call ${node.name}')
      println('  jmp .L.end.${p.ifnum}')
      println('.L.call.${p.ifnum}:')
      println('  sub rsp, 8')
      println('  mov rax, 0')
      println('  call ${node.name}')
      println('  add rsp, 8')
      println('.L.end.${p.ifnum}:')
      println('  push rax')
      p.ifnum++
      return
    }
    .sizof {
      size := node.left.typ.size()
      println('  push $size')
      return
    }
    .nothing {
      return
    }
  }

  p.gen(node.left)
  p.gen(node.right)

  println('  pop rdi')
  println('  pop rax')

  match node.kind {
    .add {println('  add rax, rdi')}
    .sub {println('  sub rax, rdi')}
    .mul {println('  imul rax, rdi')}
    .div {
      println('  cqo')
      println('  idiv rdi')
    }
    .mod {
      println('  cqo')
      println('  idiv rdi')
      println('  push rdx')
      return
    }
    else {
      println('  cmp rax, rdi')
      match node.kind {
        .eq {println('  sete al')}
        .ne {println('  setne al')}
        .gt {println('  setg al')}
        .ge {println('  setge al')}
      }
      println('  movzb rax, al')
    }
  }

  println('  push rax')
}

