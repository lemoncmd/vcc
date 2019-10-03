module main

struct Parser {
  tokens []Tok
mut:
  pos int
  locals []Lvar
  code []Node
}

enum Nodekind {
  assign
  add
  sub
  mul
  div
  eq
  ne
  gt
  ge
  num
  lvar
}

struct Node {
  kind Nodekind
  left &Node
  right &Node
  num int
  offset int
}

struct Lvar {
  name string
  offset int
}

fn (p mut Parser) consume(op string) bool {
  token := p.tokens[p.pos]
  if token.kind != .reserved || token.str != op {
    return false
  }
  p.pos++
  return true
}

fn (p mut Parser) consume_ident() ?string {
  token := p.tokens[p.pos]
  if token.kind == .ident {
    p.pos++
    return token.str
  }
  return none
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
    offset:0
  }
  return node
}

fn (p Parser) new_node_num(num int) &Node {
  node := &Node{
    kind:Nodekind.num
    left:0
    right:0
    num:num
    offset:0
  }
  return node
}

fn (p Parser) new_node_lvar(offset int) &Node {
  node := &Node{
    kind:Nodekind.lvar
    left:0
    right:0
    num:0
    offset:offset
  }
  return node
}

fn (p Parser) new_lvar(name string, offset int) &Lvar {
  lvar := &Lvar{
    name:name
    offset:offset
  }
  return lvar
}

fn (p Parser) find_lvar(name string) ?Lvar {
  for i in p.locals {
    if i.name == name {
      return i
    }
  }
  return none
}

fn (p mut Parser) program() {
  for p.tokens[p.pos].kind != .eof {
    stmt := p.stmt()
    p.code << *stmt
  }
}

fn (p mut Parser) stmt() &Node {
  node := p.expr()
  p.expect(';')
  return node
}

fn (p mut Parser) expr() &Node {
  return p.assign()
}

fn (p mut Parser) assign() &Node {
  mut node := p.equality()

  if p.consume('=') {
    node = p.new_node(.assign, node, p.assign())
  }
  return node
}

fn (p mut Parser) equality() &Node {
  mut node := p.relational()

  for {
    if p.consume('==') {
      node = p.new_node(.eq, node, p.relational())
    } else if p.consume('!=') {
      node = p.new_node(.ne, node, p.relational())
    } else {
      return node
    }
  }
  return node
}

fn (p mut Parser) relational() &Node {
  mut node := p.add()

  for {
    if p.consume('>') {
      node = p.new_node(.gt, node, p.add())
    } else if p.consume('>=') {
      node = p.new_node(.ge, node, p.add())
    } else if p.consume('<') {
      node = p.new_node(.gt, p.add(), node)
    } else if p.consume('<=') {
      node = p.new_node(.ge, p.add(), node)
    } else {
      return node
    }
  }
  return node
}

fn (p mut Parser) add() &Node {
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
  name := p.consume_ident() or {
    return p.new_node_num(p.expect_number())
  }

  lvar := p.find_lvar(name) or {
    offset := if p.locals.len == 0 {
      0
    } else {
      (p.locals.last()).offset + 8
    }
    lvar := p.new_lvar(name, offset)
    p.locals << *lvar
    node := p.new_node_lvar(lvar.offset)
    return node
  }
  return p.new_node_lvar(lvar.offset)
}

