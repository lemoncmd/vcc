module parser

import (
  src2.scanner
  src2.token
)

pub struct Parser {
mut:
  tokens []token.Token
  pos int
  tok token.Token
}

pub fn (p mut Parser) scan_all(program string) {
  s := scanner.Scanner {
    program: program
    pos: 0
    line: 1
    lpos: 0
  }
  for {
    s.skip_delimiter()
    if s.is_end() {
      break
    }
    p.tokens << s.scan()
  }
  p.tokens << s.end_of_file()
}

fn (p mut Parser) next() {
  p.pos++
  tok = p.tokens[p.pos]
}
