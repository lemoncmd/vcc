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

  println('.intel_syntax noprefix')

  for _func in parser.code {
    func := &Function(_func)
    offset := if func.locals.len == 0 {
      0
    } else {
      &Lvar(func.locals.last()).offset
    }

    parser.curfn = func

    println('.global ${func.name}')
    println('${func.name}:')
    println('  push rbp')
    println('  mov rbp, rsp')
    println('  sub rsp, $offset')

    mut fnargs := func.args
    for i := 0; i < func.num; i++ {
      reg := match fnargs.left.typ.size() {
        4 => {Reg4[i]}
        8 => {Regs[i]}
        else => {'none'}
      }
      if reg == 'none' {
        parse_err('Invalid type in arg of function ${func.name}')
      }
      println('  mov [rbp-${fnargs.left.offset}], $reg')
      fnargs = fnargs.right
    }

    parser.gen(func.content)

    println('.Lreturn${func.name}:')
    println('  mov rsp, rbp')
    println('  pop rbp')
    println('  ret')
  }
}
