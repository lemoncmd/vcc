import os

struct Parser {
  tokens []Tok
mut:
  pos int
}

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

enum Nodekind {
  add
  sub
  mul
  div
  num
}

struct Node {
  kind Nodekind
  left &Node
  right &Node
  num int
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

    if p[pos] == `+` || p[pos] == `-` || p[pos] == `*` || p[pos] == `/` || p[pos] == `(` || p[pos] == `)` {
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

fn (p mut Parser) consume(op string) bool {
  token := p.tokens[p.pos]
  if token.kind != .reserved || token.str != op {
    return false
  }
  p.pos++
  return true
}

fn (p mut Parser) expect(op string) {
  token := p.tokens[p.pos]
  if token.kind != .reserved || token.str != op {
    unexp_err(token, 'Expected $op but got ${token.str}')
  }
  p.pos++
  return
}

fn (p mut Parser) expect_number() int {
  token := p.tokens[p.pos]
  if token.kind != .num {
    unexp_err(token, 'Expected number')
  }
  p.pos++
  return token.str.int()
}

fn (p Parser) new_node(kind Nodekind, left, right &Node) &Node {
  node := &Node{
    kind:kind
    left:left
    right:right
    num:0
  }
  return node
}

fn (p Parser) new_node_num(num int) &Node {
  node := &Node{
    kind:Nodekind.num
    left:0
    right:0
    num:num
  }
  return node
}

fn (p mut Parser) expr() &Node {
  mut node := p.mul()

  for {
    if p.consume('+') {
      node = p.new_node(.add, node, p.mul())
    } else if p.consume('-') {
      node = p.new_node(.sub, node, p.mul())
    } else {
      return node
    }
  }
  return node
}

fn (p mut Parser) mul() &Node {
  mut node := p.primary()

  for {
    if p.consume('*') {
      node = p.new_node(.mul, node, p.primary())
    } else if p.consume('/') {
      node = p.new_node(.div, node, p.primary())
    } else {
      return node
    }
  }
  return node
}

fn (p mut Parser) primary() &Node {
  if p.consume('(') {
    node := p.expr()
    p.expect(')')
    return node
  }
  return p.new_node_num(p.expect_number())
}

fn gen(node &Node) {
  if node.kind == .num {
    println('  push ${node.num}')
    return
  }

  gen(node.left)
  gen(node.right)

  println('  pop rdi')
  println('  pop rax')

  match node.kind {
    .add => {println('  add rax, rdi')}
    .sub => {println('  sub rax, rdi')}
    .mul => {println('  imul rax, rdi')}
    .div => {println('  cqo
  idiv rdi')}
  }

  println('  push rax')
}

fn main(){
  args := os.args
  if args.len != 2 {
    eprintln('The number of arguments is not correct. It must be one.')
    exit(1)
  }
  
  program := args[1]
  
  mut parser := Parser{
    tokens:tokenize(program),
    pos:0
  }
  node := parser.expr()

  println('.intel_syntax noprefix
.global main
main:')

  gen(node)

  println('  pop rax
  ret')
}
