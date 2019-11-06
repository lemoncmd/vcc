module main

import os

fn parse_err(s string) {
  eprintln(s)
  exit(1)
}

fn unexp_err(token Tok, s string) {
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
  parser.gen_main()
}
