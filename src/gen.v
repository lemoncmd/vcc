module main

const (
  Regs = ['rdi', 'rsi', 'rdx', 'rcx', 'r8', 'r9']
  Reg4 = ['edi', 'esi', 'edx', 'ecx', 'r8d', 'r9d']
)

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
  cmd := if kind in [Nodekind.incb, .incf] {
    'add'
  } else {
    'sub'
  }
  if kind in [Nodekind.incb, .decb] {
    match typ.size() {
      1 => {println('  movsx rdx, byte ptr [rax]')}
      2 => {println('  movsx rdx, word ptr [rax]')}
      4 => {println('  movsxd rdx, dword ptr [rax]')}
      8 => {println('  mov rdx, [rax]')}
      else => {parse_err('you are loading something wrong')}
    }
    println('  push rdx')
  }
  if typ.kind.last() != .ptr {
    match typ.size() {
      1 => {println('  $cmd byte ptr [rax], 1')}
      2 => {println('  $cmd word ptr [rax], 1')}
      4 => {println('  $cmd dword ptr [rax], 1')}
      8 => {println('  $cmd [rax], 1')}
      else => {parse_err('you are loading something wrong')}
    }
  } else {
    size := typ.reduce().size()
    println('  $cmd [rax], $size')
  }
  if kind in [Nodekind.incf, .decf] {
    match typ.size() {
      1 => {println('  movsx rdx, byte ptr [rax]')}
      2 => {println('  movsx rdx, word ptr [rax]')}
      4 => {println('  movsxd rdx, dword ptr [rax]')}
      8 => {println('  mov rdx, [rax]')}
      else => {parse_err('you are loading something wrong')}
    }
    println('  push rdx')
  }
}

fn (p Parser) gen_load(typ &Type){
  println('  pop rax')
  match typ.size() {
    1 => {println('  movsx rax, byte ptr [rax]')}
    2 => {println('  movsx rax, word ptr [rax]')}
    4 => {println('  movsxd rax, dword ptr [rax]')}
    8 => {println('  mov rax, [rax]')}
    else => {parse_err('you are loading something wrong')}
  }
  println('  push rax')
}

fn (p Parser) gen_store(typ &Type){
  println('  pop rdi')
  println('  pop rax')
  match typ.size() {
    1 => {println('  mov [rax], dil')}
    2 => {println('  mov [rax], di')}
    4 => {println('  mov [rax], edi')}
    8 => {println('  mov [rax], rdi')}
    else => {parse_err('you are saving something wrong')}
  }
  println('  push rdi')
}

fn (p mut Parser) gen(node &Node) {
  match node.kind {
    .ret => {
      p.gen(node.left)
      println('  pop rax')
      println('  jmp .Lreturn${p.curfn.name}')
      return
    }
    .addr => {
      if node.left.kind == .lvar {
        p.gen_lval(node.left)
      } else {
        p.gen_gval(node.left)
      }
      return
    }
    .deref => {
      p.gen(node.left)
      if node.typ.kind.last() != .ary {
        p.gen_load(node.typ)
      }
      return
    }
    .incb => {
      if node.left.kind == .lvar {
        p.gen_lval(node.left)
      } else {
        p.gen_gval(node.left)
      }
      p.gen_inc(node.kind, node.left.typ)
      return
    }
    .decb => {
      if node.left.kind == .lvar {
        p.gen_lval(node.left)
      } else {
        p.gen_gval(node.left)
      }
      p.gen_inc(node.kind, node.left.typ)
      return
    }
    .incf => {
      if node.left.kind == .lvar {
        p.gen_lval(node.left)
      } else {
        p.gen_gval(node.left)
      }
      p.gen_inc(node.kind, node.left.typ)
      return
    }
    .decf => {
      if node.left.kind == .lvar {
        p.gen_lval(node.left)
      } else {
        p.gen_gval(node.left)
      }
      p.gen_inc(node.kind, node.left.typ)
      return
    }
    .block => {
      for i in node.code {
        code := &Node(i)
        p.gen(code)
      }
      return
    }
    .ifn => {
      p.gen(node.cond)
      println('  pop rax')
      println('  cmp rax, 0')
      println('  je .Lend${node.num}')
      p.gen(node.left)
      println('.Lend${node.num}:')
      return
    }
    .ifelse => {
      p.gen(node.cond)
      println('  pop rax')
      println('  cmp rax, 0')
      println('  je .Lelse${node.num}')
      p.gen(node.left)
      println('  jmp .Lend${node.num}')
      println('.Lelse${node.num}:')
      p.gen(node.right)
      println('.Lend${node.num}:')
      return
    }
    .forn => {
      p.gen(node.first)
      println('.Lbegin${node.num}:')
      p.gen(node.cond)
      println('  pop rax')
      println('  cmp rax, 0')
      println('  je .Lend${node.num}')
      p.gen(node.left)
      p.gen(node.right)
      println('  jmp .Lbegin${node.num}')
      println('.Lend${node.num}:')
      return
    }
    .while => {
      println('.Lbegin${node.num}:')
      p.gen(node.cond)
      println('  pop rax')
      println('  cmp rax, 0')
      println('  je .Lend${node.num}')
      p.gen(node.left)
      println('  jmp .Lbegin${node.num}')
      println('.Lend${node.num}:')
      return
    }
    .num => {
      println('  push ${node.num}')
      return
    }
    .string => {
      println('  push offset .L.C.${node.offset}')
      return
    }
    .lvar => {
      p.gen_lval(node)
      if node.typ.kind.last() != .ary {
        p.gen_load(node.typ)
      }
      return
    }
    .gvar => {
      p.gen_gval(node)
      if node.typ.kind.last() != .ary {
        p.gen_load(node.typ)
      }
      return
    }
    .assign => {
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
    .call => {
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
      println('  jnz .Lcall${p.ifnum}')
      println('  mov rax, 0')
      println('  call ${node.name}')
      println('  jmp .Lend${p.ifnum}')
      println('.Lcall${p.ifnum}:')
      println('  sub rsp, 8')
      println('  mov rax, 0')
      println('  call ${node.name}')
      println('  add rsp, 8')
      println('.Lend${p.ifnum}:')
      println('  push rax')
      p.ifnum++
      return
    }
    .sizof => {
      size := node.left.typ.size()
      println('  push $size')
      return
    }
  }

  p.gen(node.left)
  p.gen(node.right)

  println('  pop rdi')
  println('  pop rax')

  match node.kind {
    .add => {println('  add rax, rdi')}
    .sub => {println('  sub rax, rdi')}
    .mul => {println('  imul rax, rdi')}
    .div => {
      println('  cqo')
      println('  idiv rdi')
    }
    .mod => {
      println('  cqo')
      println('  idiv rdi')
      println('  push rdx')
      return
    }
    else => {
      println('  cmp rax, rdi')
      match node.kind {
        .eq => {println('  sete al')}
        .ne => {println('  setne al')}
        .gt => {println('  setg al')}
        .ge => {println('  setge al')}
      }
      println('  movzb rax, al')
    }
  }

  println('  push rax')
}

