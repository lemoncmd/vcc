module main

struct Parser {
  tokens []Tok
mut:
  pos int
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
  mut node := p.unary()

  for {
    if p.consume('*') {
      node = p.new_node(.mul, node, p.unary())
    } else if p.consume('/') {
      node = p.new_node(.div, node, p.unary())
    } else {
      return node
    }
  }
  return node
}

fn (p mut Parser) unary() &Node {
  if p.consume('+') {
    return p.primary()
  } else if p.consume('-') {
    return p.new_node(.sub, p.new_node_num(0), p.primary())
  }
  return p.primary()
}

fn (p mut Parser) primary() &Node {
  if p.consume('(') {
    node := p.expr()
    p.expect(')')
    return node
  }
  return p.new_node_num(p.expect_number())
}

