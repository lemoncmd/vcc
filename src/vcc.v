module main

import os
import scanner
import token
import parser
import gen.x8664

fn main() {
	program := os.read_file(os.args[1]) or { 'int a;int main() {int b;a = 2; b = 4-1; return a;}' }
	mut s := &scanner.Scanner{program, 0, 1, 0}
	mut tokens := []token.Token{}
	for {
		token := s.scan()
		// println(token)
		tokens << token
		if token.kind == .eof {
			break
		}
	}
	mut p := &parser.Parser{
		program: program
		tokens: tokens
		pos: 0
		tok: tokens[0]
	}
	p.top()
	mut g := x8664.Gen{
		globalscope: p.globalscope
		funs: p.funs
	}
	g.gen()
	println(g.out.str())
}
