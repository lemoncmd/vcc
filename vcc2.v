module main

import scanner

fn main() {
	mut s := &scanner.Scanner{'int hoge(){int aho = 3+1;}', 0, 1, 0}
	for {
		token := s.scan()
		println(token)
		if token.kind == .eof {
			break
		}
	}
}
