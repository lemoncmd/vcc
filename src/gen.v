module main

const (
  Regs = ['rdi', 'rsi', 'rdx', 'rcx', 'r8', 'r9']
)

fn (p Parser) gen_lval(node &Node) {
  if node.kind != .lvar {
    parse_err('Assignment Error: left value is not variable')
  }

  println('  mov rax, rbp')
  println('  sub rax, ${node.offset}')
  println('  push rax')
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
      p.gen_lval(node.left)
      return
    }
    .deref => {
      p.gen(node.left)
      println('  pop rax')
      println('  mov rax, [rax]')
      println('  push rax')
      return
    }
    .block => {
      for i in node.code {
        code := &Node(i)
        p.gen(code)
        println('  pop rax')
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
    .lvar => {
      p.gen_lval(node)
      println('  pop rax')
      println('  mov rax, [rax]')
      println('  push rax')
      return
    }
    .assign => {
      p.gen_lval(node.left)
      p.gen(node.right)

      println('  pop rdi')
      println('  pop rax')
      println('  mov [rax], rdi')
      println('  push rdi')
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
  }

  p.gen(node.left)
  p.gen(node.right)

  println('  pop rdi')
  println('  pop rax')

  match node.kind {
    .add => {println('  add rax, rdi')}
    .sub => {println('  sub rax, rdi')}
    .mul => {println('  imul rax, rdi')}
    .div => {println('  cqo
  idiv rdi')}
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

