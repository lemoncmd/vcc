import os

struct Tok {
  kind Token
  str string
  line int
  pos int
}

enum Token {
  eof
  reserved
  num
}

fn parse_err(s string){
  eprintln(s)
  exit(1)
}

fn unexp_err(token Tok, s string){
  eprintln('${token.line}:${token.pos}: $s')
  exit(1)
}

fn new_token(token Token, s string, line, pos int) Tok {
  return Tok{token, s, line, pos}
}

fn tokenize(p string) []Tok {
  mut tokens := []Tok
  mut pos := 0
  mut line := 1
  mut lpos := 0

  for pos < p.len {
    if p[pos] == `\n` {
      pos++
      line++
      lpos = 0
      continue
    }

    if p[pos].is_space() {
      pos++
      lpos++
      continue
    }

    if p[pos] == `+` || p[pos] == `-` {
      tokens << new_token(.reserved, p[pos++].str(), line, lpos)
      lpos++
      continue
    }

    if p[pos].is_digit() {
      start_pos := pos
      for pos < p.len && p[pos].is_digit() {
        pos++
        lpos++
      }
      tokens << new_token(.num, p.substr(start_pos, pos), line, lpos)
      continue
    }

    parse_err('$line:$lpos: Cannot tokenize')
  }

  tokens << new_token(.eof, '', line, lpos)
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
    unexp_err(token, 'Expected $op but got ${token.str}')
  }
  return
}

fn (token Tok) expect_number() int {
  if token.kind != .num {
    unexp_err(token, 'Expected number')
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
