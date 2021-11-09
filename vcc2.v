module main

import scanner
import token
import parser

fn main() {
	program := 'int hoge(){int aho = 3+1;}'
	mut s := &scanner.Scanner{program, 0, 1, 0}
	mut tokens := []token.Token{}
	for {
		token := s.scan()
		println(token)
		tokens << token
		if token.kind == .eof {
			break
		}
	}
	mut p := &parser.Parser{
		program: program
		tokens:tokens
		pos:-1
		tok:tokens[0]
	}
}
