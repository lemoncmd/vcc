module main

struct Parser {
  tokens []Tok
mut:
  pos int
  locals []voidptr // []&Lvar
  code []voidptr // []&Node
  ifnum int
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
  ret
  ifn
  ifelse
  forn
  while
  block
  call
}

struct Node {
  kind Nodekind
  cond &Node
  first &Node
  left &Node
  right &Node
  num int
  offset int
  name string
mut:
  code []voidptr
}

struct Lvar {
  name string
  offset int
}

fn (p Parser) look_for(op string) bool {
  token := p.tokens[p.pos]
  if token.kind != .reserved || token.str != op {
    return false
  }
  return true
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

fn (p Parser) new_node_with_cond(kind Nodekind, cond, left, right &Node, num int) &Node {
  node := &Node{
    kind:kind
    cond:cond
    left:left
    right:right
    num:num
    offset:0
  }
  return node
}

fn (p Parser) new_node_with_all(kind Nodekind, first, cond, left, right &Node, num int) &Node {
  node := &Node{
    kind:kind
    cond:cond
    first:first
    left:left
    right:right
    num:num
    offset:0
  }
  return node
}

fn (p Parser) new_node_num(num int) &Node {
  node := &Node{
    kind:Nodekind.num
    num:num
    offset:0
  }
  return node
}

fn (p Parser) new_node_lvar(offset int) &Node {
  node := &Node{
    kind:Nodekind.lvar
    num:0
    offset:offset
  }
  return node
}

fn (p Parser) new_node_str(kind Nodekind, name string) &Node {
  node := &Node{
    kind:kind
    num:0
    offset:0
    name:name
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

fn (p Parser) find_lvar(name string) ?voidptr {
  for i in p.locals {
    lvar := &Lvar(i)
    if lvar.name == name {
      return i
    }
  }
  return none
}

fn (p mut Parser) program() {
  for p.tokens[p.pos].kind != .eof {
    p.code << voidptr(p.stmt())
  }
}

fn (p mut Parser) stmt() &Node {
  mut node := &Node{}
  if p.consume('return') {
    node = p.new_node(.ret, p.expr(), &Node{})
    p.expect(';')
  } else if p.look_for('{') {
    node = p.block()
  } else if p.consume('if') {
    p.expect('(')
    expr := p.expr()
    p.expect(')')
    stmt_true := p.stmt()
    if p.consume('else') {
      stmt_false := p.stmt()
      node = p.new_node_with_cond(.ifelse, expr, stmt_true, stmt_false, p.ifnum)
    } else {
      node = p.new_node_with_cond(.ifn, expr, stmt_true, &Node{}, p.ifnum)
    }
    p.ifnum++
  } else if p.consume('for') {
    p.expect('(')
    mut node_tmp := &Node{}
    first := if p.consume(';') {
      p.new_node_num(0)
    } else {
      node_tmp = p.expr()
      p.expect(';')
      node_tmp
    }
    cond := if p.consume(';') {
      p.new_node_num(1)
    } else {
      node_tmp = p.expr()
      p.expect(';')
      node_tmp
    }
    right := if p.consume(')') {
      p.new_node_num(0)
    } else {
      node_tmp = p.expr()
      p.expect(')')
      node_tmp
    }
    stmt := p.stmt()
    node = p.new_node_with_all(.forn, first, cond, stmt, right, p.ifnum)
    p.ifnum++
  } else if p.consume('while') {
    p.expect('(')
    expr := p.expr()
    p.expect(')')
    stmt := p.stmt()
    node = p.new_node_with_cond(.while, expr, stmt, &Node{}, p.ifnum)
    p.ifnum++
  } else {
    node = p.expr()
    p.expect(';')
  }
  return node
}

fn (p mut Parser) block() &Node {
  mut node := p.new_node(.block, &Node{}, &Node{})
  p.expect('{')
  for !p.consume('}') {
    node.code << voidptr(p.stmt())
  }
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

  if p.consume('(') {
    p.expect(')')
    return p.new_node_str(.call, name)
  }

  lvar := p.find_lvar(name) or {
    mut offset := if p.locals.len == 0 {
      0
    } else {
      &Lvar(p.locals.last()).offset
    }
    offset += 8
    lvar := p.new_lvar(name, offset)
    p.locals << voidptr(lvar)
    node := p.new_node_lvar(lvar.offset)
    return node
  }
  return p.new_node_lvar(&Lvar(lvar).offset)
}

