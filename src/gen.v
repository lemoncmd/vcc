module main

const (
  Reg1 = ['dil', 'sil', 'dl', 'cl', 'r8b', 'r9b']
  Reg2 = ['di', 'si', 'dx', 'cx', 'r8w', 'r9w']
  Reg4 = ['edi', 'esi', 'edx', 'ecx', 'r8d', 'r9d']
  Regs = ['rdi', 'rsi', 'rdx', 'rcx', 'r8', 'r9']
)

fn (p mut Parser) gen_main() {
  println('.intel_syntax noprefix')
  println('.data')

  for name, _gvar in p.global {
    gvar := _gvar.val
    size := gvar.typ.size()
    if !gvar.is_extern && !gvar.is_type && gvar.typ.kind.last() != .func {
      if !gvar.is_static {
        println('.global $name')
      }
      println('$name:')
      println('  .zero $size')
    }
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
    maxnum := if func.num > 6 {6} else {func.num}
    for i in 0..maxnum {
      reg := match fnargs.left.typ.size() {
        1 {Reg1[i]}
        2 {Reg2[i]}
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
    for i in 6..func.num {
      reg := match fnargs.left.typ.size() {
        1 {'al'}
        2 {'ax'}
        4 {'eax'}
        8 {'rax'}
        else {'none'}
      }
      if reg == 'none' {
        parse_err('Invalid type in arg of function $name')
      }
      basenum := 8 * (i - 4)
      println('  mov rax, [rbp+$basenum]')
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
  if !node.kind in [.lvar, .deref] {
    parse_err('Assignment Error: left value is invalid')
  }

  if node.kind == .deref {
    p.gen(node.left)
    return
  }

  println('  lea rax, [rbp-${node.offset}]')
  println('  push rax')
}

fn (p mut Parser) gen_gval(node &Node) {
  if !node.kind in [.gvar, .deref] {
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
  if typ.kind.last() in [.ary, .func, .strc] {
    parse_err('you cannot inc/decrement type `${typ.str()}`')
  }
  cmd := if kind in [.incb, .incf] {
    'add'
  } else {
    'sub'
  }
  if kind in [.incb, .decb] {
    if typ.is_unsigned() {
      match typ.size() {
        1 {println('  movzx rdx, byte ptr [rax]')}
        2 {println('  movzx rdx, word ptr [rax]')}
        4 {println('  mov edx, dword ptr [rax]')}
        8 {println('  mov rdx, [rax]')}
        else {parse_err('you are loading something wrong')}
      }
    } else {
      match typ.size() {
        1 {println('  movsx rdx, byte ptr [rax]')}
        2 {println('  movsx rdx, word ptr [rax]')}
        4 {println('  movsxd rdx, dword ptr [rax]')}
        8 {println('  mov rdx, [rax]')}
        else {parse_err('you are loading something wrong')}
      }
    }
    println('  push rdx')
  }
  if typ.kind.last() != .ptr {
    match typ.size() {
      1 {println('  $cmd byte ptr [rax], 1')}
      2 {println('  $cmd word ptr [rax], 1')}
      4 {println('  $cmd dword ptr [rax], 1')}
      8 {println('  $cmd qword ptr [rax], 1')}
      else {parse_err('you are loading something wrong')}
    }
  } else {
    size := typ.reduce().size_allow_void()
    println('  $cmd qword ptr [rax], $size')
  }
  if kind in [.incf, .decf] {
    if typ.is_unsigned() {
      match typ.size() {
        1 {println('  movzx rdx, byte ptr [rax]')}
        2 {println('  movzx rdx, word ptr [rax]')}
        4 {println('  mov edx, dword ptr [rax]')}
        8 {println('  mov rdx, [rax]')}
        else {parse_err('you are loading something wrong')}
      }
    } else {
      match typ.size() {
        1 {println('  movsx rdx, byte ptr [rax]')}
        2 {println('  movsx rdx, word ptr [rax]')}
        4 {println('  movsxd rdx, dword ptr [rax]')}
        8 {println('  mov rdx, [rax]')}
        else {parse_err('you are loading something wrong')}
      }
    }
    println('  push rdx')
  }
}

fn (p Parser) gen_load(typ &Type){
  println('  pop rax')
  if typ.is_unsigned() {
    match typ.size() {
      1 {println('  movzx rax, byte ptr [rax]')}
      2 {println('  movzx rax, word ptr [rax]')}
      4 {println('  mov eax, dword ptr [rax]')}
      8 {println('  mov rax, [rax]')}
      else {parse_err('you are loading something wrong')}
    }
  } else {
    match typ.size() {
      1 {println('  movsx rax, byte ptr [rax]')}
      2 {println('  movsx rax, word ptr [rax]')}
      4 {println('  movsxd rax, dword ptr [rax]')}
      8 {println('  mov rax, [rax]')}
      else {parse_err('you are loading something wrong')}
    }
  }
  println('  push rax')
}

fn (p Parser) gen_store(typ &Type){
  println('  pop rdi')
  println('  pop rax')
  if typ.kind.last() == .bool {
    println('  cmp rdi, 0')
    println('  setne dil')
    println('  movzb rdi, dil')
  }
  match typ.size() {
    1 {println('  mov [rax], dil')}
    2 {println('  mov [rax], di')}
    4 {println('  mov [rax], edi')}
    8 {println('  mov [rax], rdi')}
    else {parse_err('you are saving something wrong')}
  }
  println('  push rdi')
}

fn (p Parser) gen_calc(kind Nodekind) {
  match kind {
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
      println('  mov rax, rdx')
    }
    .bitand {println('  and rax, rdi')}
    .bitor  {println('  or rax, rdi')}
    .bitxor {println('  xor rax, rdi')}
    .shl {
      println('  mov cl, dil')
      println('  shl rax, cl')
    }
    .shr {
      println('  mov cl, dil')
      println('  sar rax, cl')
    }
    else {
      println('  cmp rax, rdi')
      match kind {
        .eq {println('  sete al')}
        .ne {println('  setne al')}
        .gt {println('  setg al')}
        .ge {println('  setge al')}
      }
      println('  movzb rax, al')
    }
  }
}

fn (p Parser) gen_calc_unsigned(kind Nodekind, size int) {
  match kind {
    .add {println('  add rax, rdi')}
    .sub {println('  sub rax, rdi')}
    .mul {println('  mul rdi')}
    .div {
      println('  mov rdx, 0')
      println('  div rdi')
    }
    .mod {
      println('  mov rdx, 0')
      println('  div rdi')
      println('  mov rax, rdx')
    }
    .bitand {println('  and rax, rdi')}
    .bitor  {println('  or rax, rdi')}
    .bitxor {println('  xor rax, rdi')}
    .shl {
      println('  mov cl, dil')
      println('  shl rax, cl')
    }
    .shr {
      println('  mov cl, dil')
      println('  shr rax, cl')
    }
    else {
      println('  cmp rax, rdi')
      match kind {
        .eq {println('  sete al')}
        .ne {println('  setne al')}
        .gt {println('  seta al')}
        .ge {println('  setae al')}
      }
      println('  movzb rax, al')
    }
  }
  if size == 8 {return}
  println('  push rax')
  p.gen_cast(size, true, false)
  println('  pop rax')
}

fn (p mut Parser) gen_arg(node &Node, left int) {
  if left > 0 {
    p.gen_arg(node.right, left-1)
    p.gen(node.left)
  }
}

fn (p Parser) gen_cast(size int, is_unsigned bool, is_bool bool) {
  if size == 8 {return}
  if is_bool {
    println('  cmp rax, 0')
    println('  setne al')
    println('  movzb rax, al')
    return
  }
  println('  pop rax')
  if is_unsigned {
    match size {
      1 {println('  movzx rax, al')}
      2 {println('  movzx rax, ax')}
      4 {println('  lea rax, [eax]')}
    }
  } else {
    match size {
      1 {println('  movsx rax, al')}
      2 {println('  movsx rax, ax')}
      4 {println('  movsxd rax, eax')}
    }
  }
  println('  push rax')
}

fn (p mut Parser) gen(node &Node) {
  match node.kind {
    .ret {
      if node.left.kind != .nothing {
        p.gen(node.left)
        typ := p.curfn.typ
        p.gen_cast(typ.size(), typ.is_unsigned(), typ.kind.last() == .bool)
        println('  pop rax')
      }
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
      if !node.typ.kind.last() in [.ary, .func] {
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
    .bitnot {
      p.gen(node.left)
      println('  pop rax')
      println('  not rax')
      println('  push rax')
      return
    }
    .comma {
      p.gen(node.left)
      println('  pop rax')
      p.gen(node.right)
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
      p.gencontnum << node.num
      p.gen(node.left)
      p.genifnum.delete(p.genifnum.len-1)
      p.gencontnum.delete(p.gencontnum.len-1)
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
      p.gencontnum << node.num
      p.gen(node.left)
      p.genifnum.delete(p.genifnum.len-1)
      p.gencontnum.delete(p.gencontnum.len-1)
      println('.L.cont.${node.num}:')
      println('  jmp .L.begin.${node.num}')
      println('.L.end.${node.num}:')
      return
    }
    .do {
      println('.L.begin.${node.num}:')
      p.genifnum << node.num
      p.gencontnum << node.num
      p.gen(node.left)
      p.genifnum.delete(p.genifnum.len-1)
      p.gencontnum.delete(p.gencontnum.len-1)
      println('.L.cont.${node.num}:')
      p.gen(node.cond)
      println('  pop rax')
      println('  cmp rax, 0')
      println('  je .L.end.${node.num}')
      println('  jmp .L.begin.${node.num}')
      println('.L.end.${node.num}:')
      return
    }
    .swich {
      println('.L.begin.${node.num}:')
      mut i := 0
      p.gen(node.cond)
      for _cons in node.code {
        cons := &Node(_cons)
        p.gen(cons)
        println('  pop rdi')
        println('  pop rax')
        println('  cmp rax, rdi')
        println('  je .L.label.case.${node.num}.$i')
        println('  push rax')
        i++
      }
      if node.name == 'hasdefault' {
        println('  jmp .L.label.default.${node.num}')
      } else {
        println('  jmp .L.end.${node.num}')
      }
      p.genifnum << node.num
      p.gen(node.left)
      p.genifnum.delete(p.genifnum.len-1)
      println('.L.end.${node.num}:')
      return
    }
    .brk {
      if p.genifnum.len == 0 {
        parse_err('cannot break not in loop or switch statement')
      }
      ifnum := p.genifnum.last()
      println('  jmp .L.end.$ifnum')
      return
    }
    .cont {
      if p.gencontnum.len == 0 {
        parse_err('cannot continue not in loop statement')
      }
      ifnum := p.gencontnum.last()
      println('  jmp .L.cont.$ifnum')
      return
    }
    .label {
      println('.L.label.${node.name}:')
      p.gen(node.left)
      return
    }
    .gozu {
      if !node.name in p.curfn.labels {
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
      if !node.typ.kind.last() in [.ary, .func] {
        p.gen_load(node.typ)
      }
      return
    }
    .assign {
      if node.left.typ.kind.last() == .ary {
        parse_err('Assignment Error: array body is not assignable')
      } else if node.left.typ.kind.last() == .func {
        parse_err('Assignment Error: function is not assignable')
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
    .calcassign {
      if node.left.typ.kind.last() == .ary {
        parse_err('Assignment Error: array body is not assignable')
      } else if node.left.typ.kind.last() == .func {
        parse_err('Assignment Error: function is not assignable')
      }
      if node.left.kind == .lvar {
        p.gen_lval(node.left)
      } else {
        p.gen_gval(node.left)
      }
      p.gen(node.right)
      p.gen(node.left)
      println('  pop rax')
      println('  pop rdi')

      if node.left.typ.is_unsigned() {
        p.gen_calc_unsigned(node.secondkind, node.left.typ.size())
      } else {
        p.gen_calc(node.secondkind)
      }

      println('  push rax')
      p.gen_store(node.typ)
      return
    }
    .call {
      mut args := node.left
      name := if node.name == '' {
        'rdx'
      } else {
        node.name
      }
      println('  push 1')
      println('  mov rax, rsp')
      println('  and rax, 15')
      ifnum := p.ifnum
      p.ifnum++
      if node.num % 2 == 1 {
        println('  jnz .L.call.$ifnum')
      } else {
        println('  jz .L.call.$ifnum')
      }
      println('  push 0')
      println('.L.call.$ifnum:')
      p.gen_arg(args, node.num)
      if node.name == '' {
        p.gen(node.right)
        println('  pop rdx')
      }
      for i in Regs.left(node.num) {
        println('  pop $i')
      }
      println('  mov rax, 0')
      println('  call $name')
      if node.num > 6 {
        overed := 8 * (node.num - 6)
        println('  add rsp, $overed')
      }
      println('  pop rdi')
      println('  cmp rdi, 0')
      println('  jnz .L.end.$ifnum')
      println('  pop rdi')
      println('.L.end.$ifnum:')
      if node.typ.kind.last() == .bool {
        println('  movzb rax, al')
      }
      println('  push rax')
      return
    }
    .sizof {
      size := node.left.typ.size_allow_void()
      println('  push $size')
      return
    }
    .cast {
      p.gen(node.left)
      p.gen_cast(node.typ.size(), node.typ.is_unsigned(), node.typ.kind.last() == .bool)
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

  if node.typ.is_unsigned() {
    p.gen_calc_unsigned(node.kind, node.typ.size())
  } else {
    p.gen_calc(node.kind)
  }

  println('  push rax')
}

