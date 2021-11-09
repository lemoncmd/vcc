module parser

import token
import ast

pub struct Parser {
	program string
mut:
	tokens []token.Token
	pos    int
	tok    token.Token
	funs   map[string]ast.FunctionDecl
}

fn (mut p Parser) next() {
	p.pos++
	p.tok = p.tokens[p.pos]
}

[noreturn]
fn unexp_err(token token.Token, s string) {
  eprintln('${token.line}:${token.pos}: $s')
  exit(1)
}

[noreturn]
fn (p Parser) token_err(s string) {
  program := p.program.split_into_lines()[p.tok.line-1]
  here := [' '].repeat(p.tok.pos).join('')
  unexp_err(p.tok, '$s\n$program\n$here^here')
}

fn (mut p Parser) check(kind token.Kind) {
	if p.tok.kind != kind {
		p.token_err('Expected $kind')
	}
}
