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

fn gen(node &Node) {
  if node.kind == .num {
    println('  push ${node.num}')
    return
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
  node := parser.expr()

  println('.intel_syntax noprefix
.global main
main:')

  gen(node)

  println('  pop rax
  ret')
}
