module parser

import ast

fn (mut p Parser) top() {
	for p.tok.kind != .eof {
		typ, name := p.read_type()
		p.next()
		match p.tok.kind {
			.lsbr {}
			.semi {}
			else {
				p.token_err('Expected `;` after top level declaration')
			}
		}
	}
}
