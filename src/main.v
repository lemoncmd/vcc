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
    parser.gen(code)
    println('  pop rax')
  }

  println('  mov rsp, rbp')
  println('  pop rbp')
  println('  ret')
}
