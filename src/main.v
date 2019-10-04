module main

import os

fn parse_err(s string){
  eprintln(s)
  exit(1)
}

fn unexp_err(token Tok, s string){
  eprintln('${token.line}:${token.pos}: $s')
  exit(1)
}

fn gen_lval(node &Node) {
  if node.kind != .lvar {
    parse_err('Assignment Error: left value is not variable')
  }

  println('  mov rax, rbp')
  println('  sub rax, ${node.offset}')
  println('  push rax')
}

fn gen(node &Node) {
  match node.kind {
    .ret => {
      gen(node.left)
      println('  pop rax')
      println('  mov rsp, rbp')
      println('  pop rbp')
      println('  ret')
      return
    }
    .block => {
      for i in node.code {
        code := &Node(i)
        gen(code)
        println('  pop rax')
      }
      return
    }
    .ifn => {
      gen(node.cond)
      println('  pop rax')
      println('  cmp rax, 0')
      println('  je .Lend${node.num}')
      gen(node.left)
      println('.Lend${node.num}:')
      return
    }
    .ifelse => {
      gen(node.cond)
      println('  pop rax')
      println('  cmp rax, 0')
      println('  je .Lelse${node.num}')
      gen(node.left)
      println('  jmp .Lend${node.num}')
      println('.Lelse${node.num}:')
      gen(node.right)
      println('.Lend${node.num}:')
      return
    }
    .forn => {
      gen(node.first)
      println('.Lbegin${node.num}:')
      gen(node.cond)
      println('  pop rax')
      println('  cmp rax, 0')
      println('  je .Lend${node.num}')
      gen(node.left)
      gen(node.right)
      println('  jmp .Lbegin${node.num}')
      println('.Lend${node.num}:')
      return
    }
    .while => {
      println('.Lbegin${node.num}:')
      gen(node.cond)
      println('  pop rax')
      println('  cmp rax, 0')
      println('  je .Lend${node.num}')
      gen(node.left)
      println('  jmp .Lbegin${node.num}')
      println('.Lend${node.num}:')
      return
    }
    .num => {
      println('  push ${node.num}')
      return
    }
    .lvar => {
      gen_lval(node)
      println('  pop rax')
      println('  mov rax, [rax]')
      println('  push rax')
      return
    }
    .assign => {
      gen_lval(node.left)
      gen(node.right)

      println('  pop rdi')
      println('  pop rax')
      println('  mov [rax], rdi')
      println('  push rdi')
      return
    }
    .call => {
      println('  call ${node.name}')
      println('  push rax')
      return
    }
  }

  gen(node.left)
  gen(node.right)

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

fn main(){
  args := os.args
  if args.len != 2 {
    eprintln('The number of arguments is not correct. It must be one.')
    exit(1)
  }
  
  program := args[1]
  
  mut parser := Parser{
    tokens:tokenize(program),
    pos:0
  }
  parser.program()

  offset := if parser.locals.len == 0 {
    0
  } else {
    &Lvar(parser.locals.last()).offset
  }

  println('.intel_syntax noprefix')
  println('.global main')
  println('main:')
  println('  push rbp')
  println('  mov rbp, rsp')
  println('  sub rsp, $offset')

  for node in parser.code {
    code := &Node(node)
    gen(code)
    println('  pop rax')
  }

  println('  mov rsp, rbp')
  println('  pop rbp')
  println('  ret')
}
