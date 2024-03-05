module main

import os
import scanner
import token
import parser
import checker
import gen.x8664

fn main() {
	program := os.read_file(os.args[1]) or { 'int a(){}int main() {a();}' }
	mut s := &scanner.Scanner{program, 0, 1, 0}
	mut tokens := []token.Token{}
	for {
		tok := s.scan()
		tokens << tok
		if tok.kind == .eof {
			break
		}
	}
	mut p := parser.Parser{
		program: program
		tokens: tokens
		pos: 0
		tok: tokens[0]
	}
	p.top()
	mut c := checker.Checker{
		globalscope: p.globalscope
		funs: p.funs
	}
	c.top()
	mut g := x8664.Gen{
		globalscope: p.globalscope
		funs: c.funs
	}
	g.gen()
	println(g.out.str())
}
