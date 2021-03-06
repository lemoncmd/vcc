module src

const (
  Reg1 = ['dil', 'sil', 'dl', 'cl', 'r8b', 'r9b']
  Reg2 = ['di', 'si', 'dx', 'cx', 'r8w', 'r9w']
  Reg4 = ['edi', 'esi', 'edx', 'ecx', 'r8d', 'r9d']
  Regs = ['rdi', 'rsi', 'rdx', 'rcx', 'r8', 'r9']
)

pub fn (p mut Parser) gen_main() {
  println('.intel_syntax noprefix')
  println('.data')

  for name, gvar in p.global {
    if !gvar.is_extern && !gvar.is_type && gvar.typ.kind.last() != .func {
      size := gvar.typ.size()
      if !gvar.is_static {
        println('.global $name')
      }
      println('$name:')
      println('  .zero $size')
    }
  }

  for i, node in p.strs {
    offset := node.offset
    content := node.name
    println('.L.C.$offset:')
    println('  .string "$content"')
  }

  println('.text')

  for name, func in p.code {
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
      println('  mov [rbp-$fnargs.left.offset], $reg')
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
      println('  mov [rbp-$fnargs.left.offset], $reg')
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

  println('  lea rax, [rbp-$node.offset]')
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

  println('  push offset $node.name')
}

fn (p Parser) gen_inc(kind Nodekind, typ &Type){
  println('  pop rax')
  if typ.kind.last() in [.ary, .func, .strc] {
    parse_err('Cannot inc/decrement type `${*typ}`')
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
        else {parse_err('What?')}
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
        else {parse_err('What?')}
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
      else {parse_err('Unexpected size')}
    }
  } else {
    match size {
      1 {println('  movsx rax, al')}
      2 {println('  movsx rax, ax')}
      4 {println('  movsxd rax, eax')}
      else {parse_err('Unexpected size')}
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
      println('  jmp .L.return.$p.curfn.name')
    }
    .addr {
      if node.left.kind == .lvar {
        p.gen_lval(node.left)
      } else {
        p.gen_gval(node.left)
      }
    }
    .deref {
      p.gen(node.left)
      if !node.typ.kind.last() in [.ary, .func, .strc] {
        p.gen_load(node.typ)
      }
    }
    .incb, .decb, .incf, .decf {
      if node.left.kind == .lvar {
        p.gen_lval(node.left)
      } else {
        p.gen_gval(node.left)
      }
      p.gen_inc(node.kind, node.left.typ)
    }
    .bitnot {
      p.gen(node.left)
      println('  pop rax')
      println('  not rax')
      println('  push rax')
    }
    .comma {
      p.gen(node.left)
      println('  pop rax')
      p.gen(node.right)
    }
    .block {
      for code in node.code {
        p.gen(code)
      }
    }
    .ifn {
      p.gen(node.cond)
      println('  pop rax')
      println('  cmp rax, 0')
      println('  je .L.end.$node.num')
      p.gen(node.left)
      println('.L.end.$node.num:')
    }
    .ifelse {
      p.gen(node.cond)
      println('  pop rax')
      println('  cmp rax, 0')
      println('  je .L.else.$node.num')
      p.gen(node.left)
      println('  jmp .L.end.$node.num')
      println('.L.else.$node.num:')
      p.gen(node.right)
      println('.L.end.$node.num:')
    }
    .forn {
      p.gen(node.first)
      println('.L.begin.$node.num:')
      p.gen(node.cond)
      println('  pop rax')
      println('  cmp rax, 0')
      println('  je .L.end.$node.num')
      p.genifnum << node.num
      p.gencontnum << node.num
      p.gen(node.left)
      p.genifnum.delete(p.genifnum.len-1)
      p.gencontnum.delete(p.gencontnum.len-1)
      println('.L.cont.$node.num:')
      p.gen(node.right)
      println('  jmp .L.begin.$node.num')
      println('.L.end.$node.num:')
    }
    .while {
      println('.L.begin.$node.num:')
      p.gen(node.cond)
      println('  pop rax')
      println('  cmp rax, 0')
      println('  je .L.end.$node.num')
      p.genifnum << node.num
      p.gencontnum << node.num
      p.gen(node.left)
      p.genifnum.delete(p.genifnum.len-1)
      p.gencontnum.delete(p.gencontnum.len-1)
      println('.L.cont.$node.num:')
      println('  jmp .L.begin.$node.num')
      println('.L.end.$node.num:')
    }
    .do {
      println('.L.begin.$node.num:')
      p.genifnum << node.num
      p.gencontnum << node.num
      p.gen(node.left)
      p.genifnum.delete(p.genifnum.len-1)
      p.gencontnum.delete(p.gencontnum.len-1)
      println('.L.cont.$node.num:')
      p.gen(node.cond)
      println('  pop rax')
      println('  cmp rax, 0')
      println('  je .L.end.$node.num')
      println('  jmp .L.begin.$node.num')
      println('.L.end.$node.num:')
    }
    .swich {
      println('.L.begin.$node.num:')
      mut i := 0
      p.gen(node.cond)
      for cons in node.code {
        p.gen(cons)
        println('  pop rdi')
        println('  pop rax')
        println('  cmp rax, rdi')
        println('  je .L.label.case.$node.num\.$i')
        println('  push rax')
        i++
      }
      if node.name == 'hasdefault' {
        println('  jmp .L.label.default.$node.num')
      } else {
        println('  jmp .L.end.$node.num')
      }
      p.genifnum << node.num
      p.gen(node.left)
      p.genifnum.delete(p.genifnum.len-1)
      println('.L.end.$node.num:')
    }
    .brk {
      if p.genifnum.len == 0 {
        parse_err('cannot break not in loop or switch statement')
      }
      ifnum := p.genifnum.last()
      println('  jmp .L.end.$ifnum')
    }
    .cont {
      if p.gencontnum.len == 0 {
        parse_err('cannot continue not in loop statement')
      }
      ifnum := p.gencontnum.last()
      println('  jmp .L.cont.$ifnum')
    }
    .label {
      println('.L.label.$node.name:')
      p.gen(node.left)
    }
    .gozu {
      if !node.name in p.curfn.labels {
        parse_err('$node.name used in goto but not declared')
      }
      println('  jmp .L.label.$node.name')
    }
    .num {
      println('  push $node.num')
    }
    .string {
      println('  push offset .L.C.$node.offset')
    }
    .lvar {
      p.gen_lval(node)
      if !node.typ.kind.last() in [.ary, .func, .strc] {
        p.gen_load(node.typ)
      }
    }
    .gvar {
      p.gen_gval(node)
      if !node.typ.kind.last() in [.ary, .func, .strc] {
        p.gen_load(node.typ)
      }
    }
    .assign {
      if node.left.typ.kind.last() == .ary {
        parse_err('Assignment Error: array body is not assignable')
      } else if node.left.typ.kind.last() == .func {
        parse_err('Assignment Error: function is not assignable')
      } else if node.typ.kind.last() == .strc {
/*        for i in node.code {
          code := i.val
          p.gen(code)
        }*/
        return
      }
      if node.left.kind == .lvar {
        p.gen_lval(node.left)
      } else {
        p.gen_gval(node.left)
      }
      p.gen(node.right)
      p.gen_store(node.typ)
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
      for i in Regs[..node.num] {
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
    }
    .sizof {
      size := node.left.typ.size_allow_void()
      println('  push $size')
    }
    .cast {
      p.gen(node.left)
      p.gen_cast(node.typ.size(), node.typ.is_unsigned(), node.typ.kind.last() == .bool)
    }
    .nothing {
    }
    else {
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
  }
}

