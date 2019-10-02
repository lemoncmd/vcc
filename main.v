import os

struct Tok {
  kind Token
  str string
}

enum Token {
  eof
  reserved
  num
}

fn new_token(token Token, s string) Tok {
  return Tok{token, s}
}

fn tokenize(p string) []Tok {
  mut tokens := []Tok
  mut pos := 0

  for pos < p.len {
    if p[pos].is_space() {
      pos++
      continue
    }

    if p[pos] == `+` || p[pos] == `-` {
      tokens << new_token(.reserved, p[pos++].str())
      continue
    }

    if p[pos].is_digit() {
      start_pos := pos
      for pos < p.len && p[pos].is_digit() {
        pos++
      }
      tokens << new_token(.num, p.substr(start_pos, pos))
      continue
    }

    eprintln('Cannot tokenize')
  }

  tokens << new_token(.eof, '')
  return tokens
}

fn (token Tok) consume(op string) bool {
  if token.kind != .reserved || token.str != op {
    return false
  }
  return true
}

fn (token Tok) expect(op string) {
  if token.kind != .reserved || token.str != op {
    eprintln('Expected $op but got ${token.str}')
    exit(1)
  }
  return
}

fn (token Tok) expect_number() int {
  if token.kind != .num {
    eprintln('Expected number')
    exit(1)
  }
  return token.str.int()
}

fn main(){
  args := os.args
  if args.len != 2 {
    eprintln('The number of arguments is not correct. It must be one.')
    exit(1)
  }
  
  program := args[1]
  
  tokens := tokenize(program)

  println('.intel_syntax noprefix
.global main
main:')
  
  mut pos := 0
  mut num := tokens[pos].expect_number()
  pos++

  println('  mov rax, $num')

  for tokens[pos].kind != .eof {
    if tokens[pos].consume('+') {
      pos++
      num = tokens[pos].expect_number()
      pos++
      println('  add rax, $num')
      continue
    }

    tokens[pos].expect('-')
    pos++
    num = tokens[pos].expect_number()
    pos++
    println('  sub rax, $num')
  }

  println('  ret')
}
