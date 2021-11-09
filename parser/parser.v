module parser

import scanner
import token

pub struct Parser {
mut:
	tokens []token.Token
	pos    int
	tok    token.Token
}

pub fn (mut p Parser) scan_all(program string) {
	mut s := scanner.Scanner{
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

fn (mut p Parser) next() {
	p.pos++
	p.tok = p.tokens[p.pos]
}
