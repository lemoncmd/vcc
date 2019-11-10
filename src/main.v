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
  mut program := ''
  if args.len < 2 {
    eprintln('The number of arguments is not correct.')
    exit(1)
  }
  if args[1] == '-' {
    if args.len < 3 {
      eprintln('There is no input string')
      exit(1)
    }
    program = args[2]
  } else {
    cont := os.read_file(args[1]) or {
      eprintln(err)
      exit(1)
    }
    program = cont
  }

  mut parser := Parser{
    tokens:tokenize(program),
    pos:0
    statics:1972
  }
  parser.program()
  parser.gen_main()
}
