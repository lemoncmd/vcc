module main

struct Parser {
  tokens []Tok
mut:
  pos int
  code map[string]Funcwrap
  ifnum int
  curfn &Function
  global map[string]Lvarwrap
  offset int
  str_offset int
  strs []Nodewrap
}

struct Funcwrap {
  val &Function
}

struct Lvarwrap {
  val &Lvar
}

struct Nodewrap {
  val &Node
}

enum Nodekind {
  nothing
  assign
  add
  sub
  mul
  div
  mod
  eq
  ne
  gt
  ge
  num
  string
  lvar
  gvar
  ret
  ifn
  ifelse
  forn
  while
  block
  call
  args
  fnargs
  deref
  addr
  sizof
  incb
  decb
  incf
  decf
}

struct Function {
  name string
  typ &Type
mut:
  num int
  args &Node
  content &Node
  locals []voidptr // []&Lvar
}

struct Node {
  kind Nodekind
mut:
  cond &Node
  first &Node
  left &Node
  right &Node
  num int
  offset int
  name string
  code []voidptr
  typ &Type
}

struct Lvar {
  name string
  typ &Type
  is_global bool
mut:
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

fn (p mut Parser) consume_ident() (bool, string) {
  token := p.tokens[p.pos]
  if token.kind == .ident {
    p.pos++
    return true, token.str
  }
  return false, ''
}

fn (p mut Parser) consume_string() (bool, string) {
  token := p.tokens[p.pos]
  if token.kind == .string {
    p.pos++
    return true, token.str
  }
  return false, ''
}

fn (p mut Parser) consume_type() (bool, &Type, string) {
  mut token := p.tokens[p.pos]
  mut typ := &Type{}
  if token.kind != .reserved || !(token.str in ['int', 'long', 'short', 'char']) {
    return false, typ, ''
  }
  p.pos++
  match token.str {
    'char' => {
      typ.kind << Typekind.char
    }
    'int' => {
      typ.kind << Typekind.int
    }
    'short' => {
      p.consume('int')
      typ.kind << Typekind.short
    }
    'long' => {
      if p.consume('long') {
        typ.kind << Typekind.ll
      } else {
        typ.kind << Typekind.long
      }
      p.consume('int')
    }
  }
  token = p.tokens[p.pos]
  for token.kind == .reserved && token.str == '*' {
    typ.kind << Typekind.ptr
    p.pos++
    token = p.tokens[p.pos]
  }
  name := p.expect_ident()
  for p.consume('[') {
    typ.kind << Typekind.ary
    typ.suffix << p.expect_number()
    p.expect(']')
  }
  return true, typ, name
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
    unexp_err(token, 'Expected number but got ${token.str}')
  }
  p.pos++
  return token.str.int()
}

fn (p mut Parser) expect_ident() string {
  token := p.tokens[p.pos]
  if token.kind != .ident {
    unexp_err(token, 'Expected ident but got ${token.str}')
  }
  p.pos++
  return token.str
}

fn (p mut Parser) expect_type() string {
  token := p.tokens[p.pos]
  if token.kind != .reserved || !(token.str in ['int', 'short', 'long', 'char']) {
    unexp_err(token, 'Expected type but got ${token.str}')
  }
  p.pos++
  return token.str
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

fn (p Parser) new_node_string(str string, id int) &Node {
  node := &Node{
    kind:Nodekind.string
    offset:id
    name:str
  }
  return node
}

fn (p Parser) new_node_lvar(offset int, typ &Type) &Node {
  node := &Node{
    kind:Nodekind.lvar
    offset:offset
    typ:typ
  }
  return node
}

fn (p Parser) new_node_gvar(offset int, typ &Type, name string) &Node {
  node := &Node{
    kind:Nodekind.gvar
    offset:offset
    typ:typ
    name:name
  }
  return node
}

fn (p Parser) new_node_call(kind Nodekind, num int, name string, args &Node) &Node {
  node := &Node{
    kind:kind
    left:args
    num:num
    offset:0
    name:name
  }
  return node
}

fn (p Parser) new_func(name string, typ &Type) &Function {
  func := &Function{
    name: name
    typ: typ
  }
  return func
}

fn (p Parser) new_lvar(name string, typ &Type, offset int) &Lvar {
  lvar := &Lvar{
    name:name
    typ:typ
    offset:offset
  }
  return lvar
}

fn (p Parser) new_gvar(name string, typ &Type, offset int) &Lvar {
  lvar := &Lvar{
    name:name
    typ:typ
    is_global:true
  }
  return lvar
}

fn (p Parser) find_lvar(name string) (bool, &Lvar) {
  for i in p.curfn.locals {
    lvar := &Lvar(i)
    if lvar.name == name {
      return true, lvar
    }
  }
  if name in p.global {
    return true, p.global[name].val
  }
  return false, &Lvar{}
}

fn (p mut Parser) program() {
  for p.tokens[p.pos].kind != .eof {
    p.top()
  }
}

fn (p mut Parser) top() {
  mut typ := &Type{}
  match p.expect_type() {
    'char' => {
      typ.kind << Typekind.char
    }
    'int' => {
      typ.kind << Typekind.int
    }
    'short' => {
      p.consume('int')
      typ.kind << Typekind.short
    }
    'long' => {
      if p.consume('long') {
        typ.kind << Typekind.ll
      } else {
        typ.kind << Typekind.long
      }
      p.consume('int')
    }
  }
  for p.consume('*') {
    typ.kind << Typekind.ptr
  }
  name := p.expect_ident()
  if p.consume('(') {
    p.code[name] = Funcwrap{p.function(name, typ)}
  } else {
    for p.consume('[') {
      num := p.expect_number()
      typ.kind << Typekind.ary
      typ.suffix << num
      p.expect(']')
    }
    p.expect(';')
    p.global[name] = Lvarwrap{p.new_gvar(name, typ, p.offset)}
    p.offset += typ.size()
  }
}

fn (p mut Parser) fnargs() (&Node, int) {
  is_typ, typ, name := p.consume_type()
  if !is_typ {
    parse_err('Expected type')
  }
  mut lvar := p.new_lvar(name, typ, 0)
  is_lvar, glvar := p.find_lvar(name)
  if is_lvar && !(&Lvar(glvar).is_global) {
    parse_err('$name is already declared')
  }

  mut offset := if p.curfn.locals.len == 0 {
    0
  } else {
    &Lvar(p.curfn.locals.last()).offset
  }
  offset += typ.size()
  lvar.offset = offset
  p.curfn.locals << voidptr(lvar)
  lvar_node := p.new_node_lvar(lvar.offset, typ)

  if p.consume(',') {
    args, num := p.fnargs()
    return p.new_node(.fnargs, lvar_node, args), num+1
  }
  return p.new_node(.fnargs, lvar_node, &Node{}), 1
}

fn (p mut Parser) function(name string, typ &Type) &Function {
  mut func := p.new_func(name, typ)
  p.curfn = func
  mut num := 0
  mut args := &Node{}
  if !p.consume(')') {
    _args, _num := p.fnargs()
    args = _args
    num = _num
    p.expect(')')
  }
  func.args = args
  func.num = num
  func.content = p.block()
  return func
}

fn (p mut Parser) declare(typ &Type, name string) int {
  mut offset := if p.curfn.locals.len == 0 {
    0
  } else {
    &Lvar(p.curfn.locals.last()).offset
  }
  offset += typ.size()
  nlvar := p.new_lvar(name, typ, offset)
  p.curfn.locals << voidptr(nlvar)
  return offset
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
  node.add_type()
  return node
}

fn (p mut Parser) block() &Node {
  mut node := p.new_node(.block, &Node{}, &Node{})
  p.expect('{')
  for !p.consume('}') {
    is_dec, typ, name := p.consume_type()
    if is_dec {
      offset := p.declare(typ, name)
      if p.consume('=') {
        lvar := p.new_node_lvar(offset, typ)
        mut assign := p.new_node(.assign, lvar, p.expr())
        assign.add_type()
        node.code << voidptr(assign)
      }
      p.expect(';')
    } else {
      node.code << voidptr(p.stmt())
    }
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
      mut right := p.mul()
      node.add_type()
      right.add_type()
      mut typ := &Type{}
      if node.typ.is_ptr() && right.typ.is_int() {
        typ = node.typ.reduce()
        num := p.new_node_num(typ.size())
        typ.kind = node.typ.kind.clone()
        typ.suffix = node.typ.suffix.clone()
        right = p.new_node(.mul, right, num)
      } else if node.typ.is_int() && right.typ.is_ptr() {
        typ = right.typ.reduce()
        num := p.new_node_num(typ.size())
        typ.kind = node.typ.kind.clone()
        typ.suffix = node.typ.suffix.clone()
        node = p.new_node(.mul, node, num)
      } else if node.typ.is_int() && right.typ.is_int() {
        typ = type_max(node.typ, right.typ).clone()
      } else {
        parse_err('Operator + cannot add two pointers')
      }
      node = p.new_node(.add, node, right)
      node.typ = typ
    } else if p.consume('-') {
      mut right := p.mul()
      node.add_type()
      right.add_type()
      mut typ := &Type{}
      if node.typ.is_ptr() && right.typ.is_int() {
        typ = node.typ.reduce()
        num := p.new_node_num(typ.size())
        typ.kind = node.typ.kind.clone()
        typ.suffix = node.typ.suffix.clone()
        right = p.new_node(.mul, right, num)
      } else if node.typ.is_ptr() && right.typ.is_ptr() {
        typ = node.typ.reduce()
        num := p.new_node_num(typ.size())
        typ.kind = [Typekind.int]
        typ.suffix = []int
        node = p.new_node(.div, node, num)
        right = p.new_node(.div, right, num)
      } else if node.typ.is_int() && right.typ.is_int() {
        typ = type_max(node.typ, right.typ).clone()
      } else {
        parse_err('Operator - cannot sub pointers from int')
      }
      node = p.new_node(.sub, node, right)
      node.typ = typ
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
    } else if p.consume('%') {
      node = p.new_node(.mod, node, p.unary())
    } else {
      return node
    }
  }
  return node
}

fn (p mut Parser) unary() &Node {
  if p.consume('sizeof') {
    return p.new_node(.sizof, p.unary(), &Node{})
  } else if p.consume('*') {
    return p.new_node(.deref, p.unary(), &Node{})
  } else if p.consume('&') {
    return p.new_node(.addr, p.unary(), &Node{})
  } else if p.consume('+') {
    return p.unary()
  } else if p.consume('-') {
    return p.new_node(.sub, p.new_node_num(0), p.unary())
  }
  return p.postfix()
}

fn (p mut Parser) postfix() &Node {
  mut node := p.primary()

  for p.consume('[') {
    mut right := p.expr()
    node.add_type()
    right.add_type()
    mut typ := &Type{}
    if node.typ.is_ptr() && right.typ.is_int() {
      typ = node.typ.reduce()
      num := p.new_node_num(typ.size())
      typ.kind = node.typ.kind.clone()
      typ.suffix = node.typ.suffix.clone()
      right = p.new_node(.mul, right, num)
    } else if node.typ.is_int() && right.typ.is_ptr() {
      typ = right.typ.reduce()
      num := p.new_node_num(typ.size())
      typ.kind = node.typ.kind.clone()
      typ.suffix = node.typ.suffix.clone()
      node = p.new_node(.mul, node, num)
    } else if node.typ.is_int() && right.typ.is_int() {
      parse_err('either expression in a[b] should be pointer')
    } else {
      parse_err('both body and suffix are pointers in a[b] expression')
    }
    node = p.new_node(.add, node, right)
    node.typ = typ
    node = p.new_node(.deref, node, &Node{})
    p.expect(']')
  }
  return node
}

fn (p mut Parser) args() (&Node, int) {
  expr := p.expr()
  if p.consume(',') {
    args, num := p.args()
    return p.new_node(.args, expr, args), num+1
  }
  return p.new_node(.args, expr, &Node{}), 1
}

fn (p mut Parser) primary() &Node {
  if p.consume('(') {
    node := p.expr()
    p.expect(')')
    return node
  }
  is_ident, name := p.consume_ident()
  if !is_ident {
    is_string, content := p.consume_string()
    if is_string {
      node := p.new_node_string(content, p.str_offset)
      p.str_offset++
      p.strs << Nodewrap{node}
      return node
    }
    return p.new_node_num(p.expect_number())
  }

  if p.consume('(') {
    if p.consume(')') {
      return p.new_node_call(.call, 0, name, &Node{})
    } else {
      args, num := p.args()
      p.expect(')')
      return p.new_node_call(.call, num, name, args)
    }
  }

  is_lvar, lvar := p.find_lvar(name)
  if !is_lvar {
    parse_err('$name is not declared yet.')
  }
  node := if lvar.is_global {
    p.new_node_gvar(lvar.offset, lvar.typ, name)
  } else {
    p.new_node_lvar(lvar.offset, lvar.typ)
  }
  return node
}

