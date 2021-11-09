module main

import scanner

fn main() {
	mut s := &scanner.Scanner{'==', 0, 1, 0}
	token := s.scan()
	println(token.str)
}
