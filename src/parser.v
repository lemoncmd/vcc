module main

struct Parser {
  tokens []Tok
mut:
  pos int
  code map[string]Funcwrap
  ifnum int
  genifnum []int
  curfn &Function
  curbl []Nodewrap
  global map[string]Lvarwrap
  glstrc map[string]Strcwrap
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
mut:
  val &Node
}

struct Strcwrap {
mut:
  val &Struct
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
  do
  brk
  cont
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
  offset int
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
  locals []voidptr // []&Lvar
  structs map[string]Strcwrap
}

struct Lvar {
  name string
  typ &Type
  is_global bool
mut:
  offset int
}

struct Struct {
  name string
  kind Structkind
mut:
  content map[string]Lvarwrap
  offset int
}

enum Structkind {
  strc
  unn
  enm
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
    kind:.num
    num:num
    offset:0
  }
  return node
}

fn (p Parser) new_node_string(str string, id int) &Node {
  node := &Node{
    kind:.string
    offset:id
    name:str
  }
  return node
}

fn (p Parser) new_node_lvar(offset int, typ &Type) &Node {
  node := &Node{
    kind:.lvar
    offset:offset
    typ:typ
  }
  return node
}

fn (p Parser) new_node_gvar(offset int, typ &Type, name string) &Node {
  node := &Node{
    kind:.gvar
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

fn (p Parser) new_gvar(name string, typ &Type) &Lvar {
  lvar := &Lvar{
    name:name
    typ:typ
    is_global:true
  }
  return lvar
}

fn (p Parser) find_lvar(name string) (bool, &Lvar, bool) {
  mut is_curbl := true
  for block in p.curbl.reverse() {
    for i in block.val.locals {
      lvar := &Lvar(i)
      if lvar.name == name {
        return true, lvar, is_curbl
      }
    }
    is_curbl = false
  }
  if name in p.global {
    return true, p.global[name].val, false
  }
  return false, &Lvar{}, false
}

fn (p Parser) find_struct(name string) (bool, &Struct, bool) {
  mut is_curbl := true
  for _block in p.curbl.reverse() {
    block := _block.val
    if name in block.structs {
      return true, block.structs[name].val, is_curbl
    }
    is_curbl = false
  }
  if name in p.glstrc {
    return true, p.glstrc[name].val, is_curbl
  }
  return false, &Struct{}, false
}

fn (p mut Parser) program() {
  for p.tokens[p.pos].kind != .eof {
    p.top()
  }
}

fn (p mut Parser) top() {
  is_typ, mut typ := p.consume_type_base()
  if !is_typ {
    parse_err('expected type')
  }
  p.consume_type_front(mut typ)
  name := p.expect_ident()
  if p.consume('(') {
    p.code[name] = Funcwrap{p.function(name, typ)}
  } else {
    p.consume_type_back(mut typ)
    p.expect(';')
    if name in p.global {
      parse_err('duplicated global variable $name')
    }
    p.global[name] = Lvarwrap{p.new_gvar(name, typ)}
  }
}

fn (p mut Parser) fnargs() (&Node, []Lvarwrap, int) {
  is_typ, typ, name := p.consume_type()
  if !is_typ {
    parse_err('Expected type')
  }
  mut lvar := p.new_lvar(name, typ, 0)
  is_lvar, _, is_curbl := p.find_lvar(name)
  if is_lvar && is_curbl {
    parse_err('$name is already declared')
  }

  p.curfn.offset += typ.size()
  p.curfn.offset = align(p.curfn.offset, typ.size())
  offset := p.curfn.offset
  lvar.offset = offset
  lvar_node := p.new_node_lvar(lvar.offset, typ)

  if p.consume(',') {
    args, mut lvars, num := p.fnargs()
    lvars << Lvarwrap{lvar}
    return p.new_node(.fnargs, lvar_node, args), lvars, num+1
  }
  return p.new_node(.fnargs, lvar_node, &Node{}), [Lvarwrap{lvar}], 1
}

fn (p mut Parser) function(name string, typ &Type) &Function {
  mut func := p.new_func(name, typ)
  p.curfn = func
  mut num := 0
  mut args := &Node{}
  mut lvars := []Lvarwrap
  if !p.consume(')') {
    _args, _lvars, _num := p.fnargs()
    args = _args
    num = _num
    lvars << _lvars
    p.expect(')')
  }
  func.args = args
  func.num = num
  mut content := p.new_node(.block, &Node{}, &Node{})
  p.curbl << Nodewrap{content}
  for lvar in lvars {
    content.locals << voidptr(lvar.val)
  }
  p.block_without_curbl(mut content)
  p.curbl.delete(p.curbl.len-1)
  func.content = content
  return func
}

fn (p mut Parser) declare(typ &Type, name string) int {
  is_lvar, _, is_curbl := p.find_lvar(name)
  if is_lvar && is_curbl {
    parse_err('$name is already declared')
  }
  p.curfn.offset += typ.size()
  p.curfn.offset = align(p.curfn.offset, typ.size())
  offset := p.curfn.offset
  nlvar := p.new_lvar(name, typ, offset)
  mut block := p.curbl.last()
  block.val.locals << voidptr(nlvar)
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
    mut outer_block := p.new_node(.block, &Node{}, &Node{})
    p.curbl << Nodewrap{outer_block}
    mut node_tmp := &Node{}
    is_decl, fortyp, name := p.consume_type()
    offset := if is_decl {
      p.declare(fortyp, name)
    } else {
      0
    }
    first := if is_decl && p.consume('=') {
      node_tmp = p.new_node(.assign, p.new_node_lvar(offset, fortyp), p.expr())
      node_tmp.add_type()
      p.expect(';')
      node_tmp
    } else if p.consume(';') {
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
    p.curbl.delete(p.curbl.len-1)
    node = p.new_node_with_all(.forn, first, cond, stmt, right, p.ifnum)
    p.ifnum++
  } else if p.consume('while') {
    p.expect('(')
    expr := p.expr()
    p.expect(')')
    stmt := p.stmt()
    node = p.new_node_with_cond(.while, expr, stmt, &Node{}, p.ifnum)
    p.ifnum++
  } else if p.consume('do') {
    stmt := p.stmt()
    p.expect('while')
    p.expect('(')
    expr := p.expr()
    p.expect(')')
    p.expect(';')
    node = p.new_node_with_cond(.do, expr, stmt, &Node{}, p.ifnum)
    p.ifnum++
  } else if p.consume('break') {
    node = p.new_node(.brk, &Node{}, &Node{})
    p.expect(';')
  } else if p.consume('continue') {
    node = p.new_node(.cont, &Node{}, &Node{})
    p.expect(';')
  } else if p.consume(';') {
    node = p.new_node(.nothing, &Node{}, &Node{})
  } else {
    node = p.expr()
    p.expect(';')
  }
  node.add_type()
  return node
}

fn (p mut Parser) block() &Node {
  mut node := p.new_node(.block, &Node{}, &Node{})
  p.curbl << Nodewrap{node}

  p.block_without_curbl(mut node)

  p.curbl.delete(p.curbl.len-1)
  return node
}

fn (p mut Parser) block_without_curbl(node mut Node) {
  p.expect('{')
  for !p.consume('}') {
    is_dec, typ_base := p.consume_type_base()
    if is_dec {
      mut first := true
      for !p.consume(';') {
        mut typ := typ_base.clone()
        if first {
          first = false
        } else {
          p.expect(',')
        }
        p.consume_type_front(mut typ)
        name := p.expect_ident()
        p.consume_type_back(mut typ)
        offset := p.declare(typ, name)
        if p.consume('=') {
          lvar := p.new_node_lvar(offset, typ)
          mut assign := p.new_node(.assign, lvar, p.expr())
          assign.add_type()
          node.code << voidptr(assign)
        }
      }
    } else {
      node.code << voidptr(p.stmt())
    }
  }
}

fn (p mut Parser) expr() &Node {
  return p.assign()
}

fn (p mut Parser) assign() &Node {
  mut node := p.ternary()

  if p.consume('=') {
    node = p.new_node(.assign, node, p.assign())
  }
  return node
}

fn (p mut Parser) ternary() &Node {
  mut node := p.equality()
  if p.consume('?') {
    expr_true := p.ternary()
    p.expect(':')
    node = p.new_node_with_cond(.ifelse, node, expr_true, p.ternary(), p.ifnum)
    p.ifnum++
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
  } else if p.consume('++') {
    return p.new_node(.incf, p.unary(), &Node{})
  } else if p.consume('--') {
    return p.new_node(.decf, p.unary(), &Node{})
  } else if p.consume('+') {
    return p.unary()
  } else if p.consume('-') {
    return p.new_node(.sub, p.new_node_num(0), p.unary())
  }
  return p.postfix()
}

fn (p mut Parser) postfix() &Node {
  mut node := p.primary()

  if p.consume('++') {
    node = p.new_node(.incb, node, &Node{})
  } else if p.consume('--') {
    node = p.new_node(.decb, node, &Node{})
  }
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

  is_lvar, lvar, _ := p.find_lvar(name)
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

