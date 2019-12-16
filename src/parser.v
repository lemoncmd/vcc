module main

struct Parser {
  tokens []Tok
  progstr string
mut:
  pos int
  code map[string]Funcwrap
  ifnum int
  genifnum []int
  gencontnum []int
  curfn &Function
  curbl []Nodewrap
  cursw []Nodewrap
  global map[string]Lvarwrap
  glstrc map[string]Strcwrap
  str_offset int
  strs []Nodewrap
  statics int
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

struct Funcargwrap{
mut:
  val &Funcarg
}

enum Nodekind {
  nothing
  assign
  calcassign
  add
  sub
  mul
  div
  mod
  bitand
  bitor
  bitxor
  bitnot
  shr
  shl
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
  swich
  brk
  cont
  block
  label
  gozu
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
  comma
  cast
}

struct Function {
  name string
  typ &Type
mut:
  num int
  args &Node
  content &Node
  offset int
  labels []string
  is_static bool
  is_defined bool
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
  secondkind Nodekind
  code []Nodewrap
  typ &Type
  locals []Lvarwrap
  structs map[string]Strcwrap
}

struct Lvar {
  name string
  typ &Type
  is_global bool
mut:
  is_static bool
  is_extern bool
  is_type bool
  offset int
}

struct Struct {
  name string
  kind Structkind
mut:
  is_defined bool
  content map[string]Lvarwrap
  offset int
  max_align int
}

enum Structkind {
  strc
  unn
  enm
}

struct Funcarg {
mut:
  args []Lvarwrap
}

fn (p Parser) look_for(op string) bool {
  token := p.tokens[p.pos]
  if token.kind != .reserved || token.str != op {
    return false
  }
  return true
}

fn (p mut Parser) look_for_label() bool {
  is_ident, _ := p.consume_ident()
  if !is_ident {
    return false
  } else {
    is_label := p.look_for(':')
    p.pos--
    return is_label
  }
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

fn (p mut Parser) consume_any(ops []string) (bool, string) {
  token := p.tokens[p.pos]
  if token.kind == .reserved && token.str in ops {
    p.pos++
    return true, token.str
  }
  return false, ''
}

fn (p mut Parser) expect(op string) {
  token := p.tokens[p.pos]
  if token.kind != .reserved || token.str != op {
    p.token_err('Expected $op but got $token.str')
  }
  p.pos++
  return
}

fn (p mut Parser) expect_number() int {
  token := p.tokens[p.pos]
  if token.kind != .num {
    p.token_err('Expected number but got $token.str')
  }
  p.pos++
  return token.str.int()
}

fn (p mut Parser) expect_ident() string {
  token := p.tokens[p.pos]
  if token.kind != .ident {
    p.token_err('Expected ident but got $token.str')
  }
  p.pos++
  return token.str
}

fn (p Parser) new_node(kind Nodekind, left, right &Node) &Node {
  return &Node{
    kind:kind
    left:left
    right:right
    num:0
    offset:0
    typ:0
    cond:0
    first:0
  }
}

fn (p Parser) new_node_with_cond(kind Nodekind, cond, left, right &Node, num int) &Node {
  return &Node{
    kind:kind
    cond:cond
    left:left
    right:right
    num:num
    first:0
    typ:0
  }
}

fn (p Parser) new_node_with_all(kind Nodekind, first, cond, left, right &Node, num int) &Node {
  return &Node{
    kind:kind
    cond:cond
    first:first
    left:left
    right:right
    num:num
    typ:0
  }
}

fn (p Parser) new_node_num(num int) &Node {
  return &Node{
    kind:.num
    num:num
    left:0
    right:0
    typ:0
    cond:0
    first:0
  }
}

fn (p Parser) new_node_string(str string, id int) &Node {
  return &Node{
    kind:.string
    offset:id
    name:str
    left:0
    right:0
    typ:0
    cond:0
    first:0
  }
}

fn (p Parser) new_node_lvar(offset int, typ &Type) &Node {
  return &Node{
    kind:.lvar
    offset:offset
    typ:typ
    left:0
    right:0
    cond:0
    first:0
  }
}

fn (p Parser) new_node_gvar(offset int, typ &Type, name string) &Node {
  return &Node{
    kind:.gvar
    offset:offset
    typ:typ
    name:name
    left:0
    right:0
    cond:0
    first:0
  }
}

fn (p Parser) new_node_call(num int, name string, args &Node) &Node {
  return &Node{
    kind:.call
    left:args
    right:0
    typ:0
    cond:0
    first:0
    num:num
    name:name
  }
}

fn (p Parser) new_node_nothing() &Node {
  return &Node{
    kind:.nothing
    left:0
    right:0
    typ:0
    cond:0
    first:0
  }
}

fn (p Parser) new_func(name string, typ &Type) &Function {
  return &Function{
    name: name
    typ: typ
    args:0
    content:0
  }
}

fn (p Parser) new_lvar(name string, typ &Type, offset int) &Lvar {
  return &Lvar{
    name:name
    typ:typ
    offset:offset
  }
}

fn (p Parser) new_gvar(name string, typ &Type) &Lvar {
  return &Lvar{
    name:name
    typ:typ
    is_global:true
  }
}

fn (p Parser) find_lvar(name string) (bool, &Lvar, bool) {
  mut is_curbl := true
  for block in p.curbl.reverse() {
    for i in block.val.locals {
      lvar := i.val
      if lvar.name == name {
        return true, lvar, is_curbl
      }
    }
    is_curbl = false
  }
  if name in p.global {
    return true, p.global[name].val, is_curbl
  }
  return false, &Lvar{typ:0}, false
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
  is_static := p.consume('static')
  if is_static {p.consume('inline')}
  is_extern := if is_static {
    false
  } else if p.consume('inline') {
    true
  } else if p.consume('extern') {
    !p.consume('inline')
  } else {
    false
  }
  is_typedef := if is_static || is_extern {
    false
  } else {
    p.consume('typedef')
  }
  is_typ, typ, mut name := p.consume_type_allow_no_ident()
  if !is_typ {
    p.token_err('Expected type')
  }
  if name == '' {
    p.expect(';')
    return
  }
  if name in p.global {//todo
    gvar := p.global[name].val
    if gvar.typ.kind.last() == .func && typ.kind.last() == .func {
      if is_typedef || gvar.is_type {
        p.token_err('`$name` is already declared')
      }
    } else {
      p.token_err('`$name` is already declared')
    }
  }
  mut gvar := p.new_gvar(name, typ)
  gvar.is_static = is_static
  gvar.is_extern = is_extern
  gvar.is_type = is_typedef
  p.global[name] = Lvarwrap{gvar}
  if p.consume('{') {
    if typ.kind.last() != .func {
      p.token_err('Expected `;` after top level declarator')
    }
    mut func := p.function(name, typ)
    func.is_static = is_static
    p.code[name] = Funcwrap{func}
  } else {
    for !p.consume(';') {
      p.expect(',')
      mut typ2 := &Type{}
      typ2.kind << typ.kind.first()
      typb, str := p.consume_type_body()
      name = str
      typ2.merge(typb)
      if name == '' {
        p.token_err('There must be name in the definition')
      }
      if name in p.global {//todo
        p.token_err('`$name` is already declared')
      }
      mut gvar2 := p.new_gvar(name, typ2)
      gvar2.is_static = is_static
      gvar2.is_extern = is_extern
      gvar2.is_type = is_typedef
      p.global[name] = Lvarwrap{gvar2}
    }
  }
}

fn (p mut Parser) fnargs(args &Funcarg) (&Node, []Lvarwrap) {
  mut lvars := []Lvarwrap
  mut node := p.new_node_nothing()
  for arg in args.args {
    name := arg.val.name
    typ := arg.val.typ
    if name == '' {
      p.token_err('Parameter name omitted')
    }
    mut lvar := p.new_lvar(name, typ, 0)
    p.curfn.offset += typ.size()
    p.curfn.offset = align(p.curfn.offset, typ.size_align())
    offset := p.curfn.offset
    lvar.offset = offset
    lvars << Lvarwrap{lvar}
  }
  for _lvar in lvars.reverse() {
    lvar := _lvar.val
    lvar_node := p.new_node_lvar(lvar.offset, lvar.typ)
    node = p.new_node(.fnargs, lvar_node, node)
  }
  return node, lvars
}

fn (p mut Parser) function(name string, typ &Type) &Function {
/*  is_struct_return := typ.size() > 16
  mut rettyp := typ.reduce()
  if is_struct_return {
    rettyp.kind << Typekind.ptr
  }*/
  mut func := p.new_func(name, typ.reduce())
  p.curfn = func
  funcarg := typ.func.last()
  num := funcarg.val.args.len
  args, lvars := p.fnargs(funcarg.val)

  func.args = args
  func.num = num
  mut content := p.new_node(.block, p.new_node_nothing(), p.new_node_nothing())
  p.curbl << Nodewrap{content}
  content.locals << lvars
  p.block_without_curbl(mut content)
  p.curbl.delete(p.curbl.len-1)
  func.content = content
  p.curfn = 0
  return func
}

fn (p mut Parser) declare(typ &Type, name string, is_typedef bool) int {
  is_lvar, _, is_curbl := p.find_lvar(name)
  if is_lvar && is_curbl {
    p.token_err('`$name` is already declared')
  }
  if !is_typedef {
    p.curfn.offset += typ.size()
    p.curfn.offset = align(p.curfn.offset, typ.size_align())
  }
  offset := p.curfn.offset
  mut nlvar := p.new_lvar(name, typ, offset)
  nlvar.is_type = is_typedef
  mut block := p.curbl.last()
  block.val.locals << Lvarwrap{nlvar}
  return offset
}

fn (p mut Parser) initialize(typ &Type, offset int) {
  if typ.kind.last() == .ary {
  } else if typ.kind.last() == .strc {
    members := (typ.strc.last()).val.content
    mut ignored := (members.keys()).len == 0
    mut keys := [['']]
    keys.delete(0)
    mut first := true
    for !p.consume('}') {
      if first {
        first = false
      } else {
        p.expect(',')
      }
      if p.consume('.') {
        name := p.expect_ident()
        p.expect('=')
        if !name in members {
          p.token_err('There is no member called `$name`')
        }
      }
      member := members[keys[0][0]].val
      if p.consume('{')/*member.typ.kind.last() in [.array, .strc]*/ {
      } else {
        node := p.assign()
        if !ignored {
          ignored=true//stab
          keys<<[['']]//stab
        }
      }
    }
  } else {
    if p.consume('{') {
      p.initialize(typ, offset)
    } else {
      node := p.assign()
    }
    for p.consume(',') {
      if p.consume('{') {
        p.initialize(typ, offset)
      } else {
        p.assign()
      }
    }
    p.expect('}')
  }
}

fn (p mut Parser) stmt() &Node {
  mut node := p.new_node_nothing()
  if p.consume('return') {
    if !p.consume(';') {
      node = p.expr()
      p.expect(';')
    }
    node = p.new_node(.ret, node, p.new_node_nothing())
  } else if p.consume('{') {
    node = p.block()
  } else if p.consume('if') {
    p.expect('(')
    expr := p.expr()
    p.expect(')')
    stmt_true := p.stmt()
    if p.consume('else') {
      stmt_false := p.stmt()
      node = p.new_node_with_cond(.ifelse, expr, stmt_true, stmt_false, p.ifnum)
      node.name = 'stmt'
    } else {
      node = p.new_node_with_cond(.ifn, expr, stmt_true, p.new_node_nothing(), p.ifnum)
    }
    p.ifnum++
  } else if p.consume('for') {
    p.expect('(')
    mut outer_block := p.new_node(.block, p.new_node_nothing(), p.new_node_nothing())
    p.curbl << Nodewrap{outer_block}
    mut node_tmp := p.new_node_nothing()
    if p.consume('typedef') || p.consume('static') {
      p.token_err('Declaration of non-local variable in `for` loop')
    }
    is_decl, fortyp := p.consume_type_base()
    if is_decl {
      mut first := true
      for !p.consume(';') {
        mut typ := fortyp.clone()
        if first {
          first = false
        } else {
          p.expect(',')
        }
        typb, name := p.consume_type_body()
        typ.merge(typb)
        if name == '' {
          p.token_err('There must be name in the definition')
        }
        p.check_func_typ(typ)
        offset := p.declare(typ, name, false)
        if p.consume('='){
          lvar := p.new_node_lvar(offset, typ)
          mut assign := p.new_node(.assign, lvar, p.assign())
          assign.add_type()
          outer_block.code << Nodewrap{assign}
        }
      }
    }
    first := if is_decl || p.consume(';') {
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
    outer_block.code << Nodewrap{p.new_node_with_all(.forn, first, cond, stmt, right, p.ifnum)}
    p.curbl.delete(p.curbl.len-1)
    node = outer_block
    p.ifnum++
  } else if p.consume('while') {
    p.expect('(')
    expr := p.expr()
    p.expect(')')
    stmt := p.stmt()
    node = p.new_node_with_cond(.while, expr, stmt, p.new_node_nothing(), p.ifnum)
    p.ifnum++
  } else if p.consume('do') {
    stmt := p.stmt()
    p.expect('while')
    p.expect('(')
    expr := p.expr()
    p.expect(')')
    p.expect(';')
    node = p.new_node_with_cond(.do, expr, stmt, p.new_node_nothing(), p.ifnum)
    p.ifnum++
  } else if p.consume('switch') {
    p.expect('(')
    expr := p.expr()
    p.expect(')')
    node = p.new_node_with_cond(.swich, expr, p.new_node_nothing(), p.new_node_nothing(), p.ifnum)
    p.ifnum++
    p.cursw << Nodewrap{node}
    mut block := p.new_node(.block, p.new_node_nothing(), p.new_node_nothing())
    block.secondkind = .swich
    p.curbl << Nodewrap{block}
    p.expect('{')
    p.block_without_curbl(mut block)
    p.curbl.delete(p.curbl.len-1)
    p.cursw.delete(p.cursw.len-1)
    node.left = block
  } else if p.consume('break') {
    node = p.new_node(.brk, p.new_node_nothing(), p.new_node_nothing())
    p.expect(';')
  } else if p.consume('continue') {
    node = p.new_node(.cont, p.new_node_nothing(), p.new_node_nothing())
    p.expect(';')
  } else if p.consume('goto') {
    node = p.new_node(.gozu, p.new_node_nothing(), p.new_node_nothing())
    node.name = p.expect_ident()
    p.expect(';')
  } else if p.consume('case') {
    if (p.curbl.last()).val.secondkind != .swich {
      p.token_err('`case` should be in switch block')
    }
    mut swblock := (p.cursw.last()).val
    value := p.ternary()
    p.expect(':')
    num := swblock.num
    id := swblock.offset
    swblock.offset++
    swblock.code << Nodewrap{value}
    node = p.new_node(.label, p.stmt(), p.new_node_nothing())
    node.name = 'case.$num\.$id'
  } else if p.consume('default') {
    if (p.curbl.last()).val.secondkind != .swich {
      p.token_err('`case` should be in switch block')
    }
    mut swblock := (p.cursw.last()).val
    p.expect(':')
    num := swblock.num
    swblock.name = 'hasdefault'
    node = p.new_node(.label, p.stmt(), p.new_node_nothing())
    node.name = 'default.$num'
  } else if p.consume(';') {
    node = p.new_node(.nothing, p.new_node_nothing(), p.new_node_nothing())
  } else if p.look_for_label() {
    name := p.expect_ident()
    if name in p.curfn.labels {
      p.token_err('Label `$name` is already declared')
    }
    p.curfn.labels << name
    p.expect(':')
    node = p.new_node(.label, p.stmt(), p.new_node_nothing())
    node.name = name
  } else {
    node = p.expr()
    p.expect(';')
  }
  node.add_type()
  return node
}

fn (p mut Parser) block() &Node {
  mut node := p.new_node(.block, p.new_node_nothing(), p.new_node_nothing())
  p.curbl << Nodewrap{node}

  p.block_without_curbl(mut node)

  p.curbl.delete(p.curbl.len-1)
  return node
}

fn (p mut Parser) block_without_curbl(node mut Node) {
  for !p.consume('}') {
    is_static := p.consume('static')
    is_typedef := if is_static {
      false
    } else {
      p.consume('typedef')
    }
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
        typb, name := p.consume_type_body()
        typ.merge(typb)
        p.check_func_typ(typ)
        if is_static {
          is_lvar, _, is_curbl := p.find_lvar(name)
          if is_lvar && is_curbl {
            p.token_err('`$name` is already declared')
          }
          p.statics++
          offset := p.statics
          mut lvar := p.new_lvar(name, typ, offset)
          lvar.is_static = true
          p.global['$name\.$offset'] = Lvarwrap{lvar}
          mut block := p.curbl.last()
          block.val.locals << Lvarwrap{lvar}
        } else if typ.kind.last() == .func {
          is_lvar, _, is_curbl := p.find_lvar(name)
          if is_lvar && is_curbl {
            p.token_err('`$name` is already declared')
          }
          mut lvar := p.new_lvar(name, typ, 0)
          mut block := p.curbl.last()
          block.val.locals << Lvarwrap{lvar}
          } else {
          offset := p.declare(typ, name, is_typedef)
          if !is_typedef && p.consume('=') {
            lvar := p.new_node_lvar(offset, typ)
            mut assign := p.new_node(.assign, lvar, p.assign())
            assign.add_type()
            node.code << Nodewrap{assign}
          }
        }
      }
    } else {
      if is_static || is_typedef {
        p.token_err('Expected type')
      }
      node.code << Nodewrap{p.stmt()}
    }
  }
}

fn (p mut Parser) expr() &Node {
  mut node := p.assign()
  for {
    if p.consume(',') {
      node = p.new_node(.comma, node, p.assign())
    } else {
      return node
    }
  }
  return node
}

/*fn (p Parser) assign_struct(node &Node) &Node {
  mut comma := p.new_node_num(0)
  strc := (node.typ.strc.last()).val
  for _, _member in strc.content {
    member := _member.val
    mut left := p.new_node(.add, node.left, p.new_node_num(member.offset))
    left.typ = member.typ.clone()
    left.typ.kind << Typekind.ptr
    left = p.new_node(.deref, left, p.new_node_nothing())
    mut right := p.new_node(.add, node.right, p.new_node_num(member.offset))
    right.typ = member.typ.clone()
    right.typ.kind << Typekind.ptr
    right = p.new_node(.deref, right, p.new_node_nothing())
    mut assign := p.new_node(.assign, left, right)
    assign.add_type()
    if assign.typ.kind.last() == .strc {
      assign = p.assign_struct(assign)
    } else if assign.typ.kind.last() == .ary {
      assign = p.assign_array(assign)
    }
    comma = p.new_node(.comma, comma, assign)
  }
  comma = p.new_node(.comma, comma, node.left)
  return comma
}

fn (p Parser) assign_array(node &Node) &Node {
  mut comma := p.new_node_num(0)
  size := node.typ.reduce().size()
  for i in 0..node.typ.suffix.last() {
    mut left := p.new_node(.add, node.left.left, p.new_node_num(i*size))
    left.typ = node.left.typ.cast_ary()
  }
  comma = p.new_node(.comma, comma, node.left)
  return comma
}*/

fn (p mut Parser) assign() &Node {
  mut node := p.ternary()

  if p.consume('=') {
    node = p.new_node(.assign, node, p.assign())
    node.add_type()
    if node.typ.kind.last() == .strc {
      if node.right.typ.kind.last() != .strc {
        p.token_err('Incompatible type when assigning to struct')
      } else if (node.typ.strc.last()).val != (node.right.typ.strc.last()).val {
        p.token_err('Incompatible struct when assigning')
      }
//      node = p.assign_struct(node)
        typ := node.typ.clone()
        node = p.new_node(.args, node.left, p.new_node(.args, node.right, p.new_node(.args, p.new_node_num(node.typ.size()), p.new_node_nothing())))
        node.add_type()
        node = p.new_node_call(3, 'memcpy', node)
        node.typ = typ
    }
  } else {
    is_assign, op := p.consume_any(['+=', '-=', '*=', '/=', '%=', '&=', '|=', '^=', '<<=', '>>='])
    if is_assign {
      node.add_type()
      mut calcee := p.assign()
      if node.typ.kind.last() == .ptr {
        body := node.typ.reduce()
        calcee = p.new_node(.mul, calcee, p.new_node_num(body.size_allow_void()))
      }
      node = p.new_node(.calcassign, node, calcee)
      node.secondkind = match op {
        '+=' {Nodekind.add}
        '-=' {Nodekind.sub}
        '*=' {Nodekind.mul}
        '/=' {Nodekind.div}
        '%=' {Nodekind.mod}
        '&=' {Nodekind.bitand}
        '|=' {Nodekind.bitor}
        '^=' {Nodekind.bitxor}
        '<<=' {Nodekind.shl}
        '>>=' {Nodekind.shr}
        else {.nothing}
      }
    }
  }
  return node
}

fn (p mut Parser) ternary() &Node {
  mut node := p.logor()
  if p.consume('?') {
    expr_true := p.expr()
    p.expect(':')
    node = p.new_node_with_cond(.ifelse, node, expr_true, p.ternary(), p.ifnum)
    p.ifnum++
  }
  return node
}

fn (p mut Parser) logor() &Node {
  mut node := p.logand()

  for {
    if p.consume('||') {
      node = p.new_node_with_cond(.ifelse, node, p.new_node_num(1), p.new_node(.ne, p.logand(), p.new_node_num(0)), p.ifnum)
      p.ifnum++
    } else {
      return node
    }
  }
  return node
}

fn (p mut Parser) logand() &Node {
  mut node := p.bitor()

  for {
    if p.consume('&&') {
      node = p.new_node_with_cond(.ifelse, node, p.new_node(.ne, p.bitor(), p.new_node_num(0)), p.new_node_num(0), p.ifnum)
      p.ifnum++
    } else {
      return node
    }
  }
  return node
}

fn (p mut Parser) bitor() &Node {
  mut node := p.bitxor()

  for {
    if p.consume('|') {
      node = p.new_node(.bitor, node, p.bitxor())
    } else {
      return node
    }
  }
  return node
}

fn (p mut Parser) bitxor() &Node {
  mut node := p.bitand()

  for {
    if p.consume('^') {
      node = p.new_node(.bitxor, node, p.bitand())
    } else {
      return node
    }
  }
  return node
}

fn (p mut Parser) bitand() &Node {
  mut node := p.equality()

  for {
    if p.consume('&') {
      node = p.new_node(.bitand, node, p.equality())
    } else {
      return node
    }
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
  mut node := p.shift()

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

fn (p mut Parser) shift() &Node {
  mut node := p.add()

  for {
    if p.consume('<<') {
      node = p.new_node(.shl, node, p.add())
    } else if p.consume('>>') {
      node = p.new_node(.shr, node, p.add())
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
      plus_token := p.tokens[p.pos]
      mut right := p.mul()
      node.add_type()
      right.add_type()
      mut typ := &Type{}
      if node.typ.is_ptr() && right.typ.is_int() {
        typ = node.typ.reduce()
        num := p.new_node_num(typ.size_allow_void())
        typ = node.typ.cast_ary()
        right = p.new_node(.mul, right, num)
        right.typ = typ.clone()
      } else if node.typ.is_int() && right.typ.is_ptr() {
        typ = right.typ.reduce()
        num := p.new_node_num(typ.size_allow_void())
        typ = right.typ.cast_ary()
        node = p.new_node(.mul, node, num)
        node.typ = typ.clone()
      } else if node.typ.is_int() && right.typ.is_int() {
        typ = type_max(node.typ, right.typ).clone()
      } else {
        unexp_err(plus_token, 'Operator + cannot add two pointers')
      }
      node = p.new_node(.add, node, right)
      node.typ = typ
    } else if p.consume('-') {
      minus_token := p.tokens[p.pos]
      mut right := p.mul()
      node.add_type()
      right.add_type()
      mut typ := &Type{}
      if node.typ.is_ptr() && right.typ.is_int() {
        typ = node.typ.reduce()
        num := p.new_node_num(typ.size_allow_void())
        typ = node.typ.cast_ary()
        right = p.new_node(.mul, right, num)
      } else if node.typ.is_ptr() && right.typ.is_ptr() {
        typ = node.typ.reduce()
        num := p.new_node_num(typ.size_allow_void())
        typ.kind = [Typekind.long]
        typ.suffix = []
        node = p.new_node(.div, node, num)
        right = p.new_node(.div, right, num)
      } else if node.typ.is_int() && right.typ.is_int() {
        typ = type_max(node.typ, right.typ).clone()
      } else {
        unexp_err(minus_token, 'Operator - cannot subtract pointers from int')
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
  mut node := p.cast()

  for {
    if p.consume('*') {
      node = p.new_node(.mul, node, p.cast())
    } else if p.consume('/') {
      node = p.new_node(.div, node, p.cast())
    } else if p.consume('%') {
      node = p.new_node(.mod, node, p.cast())
    } else {
      return node
    }
  }
  return node
}

fn (p mut Parser) cast() &Node {
  if p.look_for_bracket_with_type() {
    p.expect('(')
    _, typ := p.consume_type_nostring()
    if typ.kind.last() in [.ary, .func, .strc] {
      p.token_err('Cannot cast to `${*typ}`')
    }
    p.expect(')')
    mut node := p.cast()
    node.add_type()
    node.typ = node.typ.cast_ary()
    node = p.new_node(.cast, node, p.new_node_nothing())
    node.typ = typ
    return node
  }
  return p.unary()
}

fn (p mut Parser) unary() &Node {
  if p.consume('sizeof') {
    if p.look_for_bracket_with_type() {
      p.expect('(')
      is_typ, typ := p.consume_type_nostring()
      if !is_typ {
        p.token_err('Expected type')
      }
      p.expect(')')
      mut node := p.new_node_num(0)
      node.typ = typ
      return p.new_node(.sizof, node, p.new_node_nothing())
    }
    return p.new_node(.sizof, p.unary(), p.new_node_nothing())
  } else if p.consume('*') {
    return p.new_node(.deref, p.unary(), p.new_node_nothing())
  } else if p.consume('&') {
    return p.new_node(.addr, p.unary(), p.new_node_nothing())
  } else if p.consume('++') {
    return p.new_node(.incf, p.unary(), p.new_node_nothing())
  } else if p.consume('--') {
    return p.new_node(.decf, p.unary(), p.new_node_nothing())
  } else if p.consume('+') {
    return p.unary()
  } else if p.consume('-') {
    return p.new_node(.sub, p.new_node_num(0), p.unary())
  } else if p.consume('~') {
    return p.new_node(.bitnot, p.unary(), p.new_node_nothing())
  } else if p.consume('!') {
    return p.new_node(.eq, p.unary(), p.new_node_num(0))
  }
  return p.postfix()
}

fn (p mut Parser) postfix() &Node {
  mut node := p.primary()

  for {
    if p.consume('++') {
      node = p.new_node(.incb, node, p.new_node_nothing())
    } else if p.consume('--') {
      node = p.new_node(.decb, node, p.new_node_nothing())
    } else if p.consume('[') {
      mut right := p.expr()
      node.add_type()
      right.add_type()
      mut typ := &Type{}
      if node.typ.is_ptr() && right.typ.is_int() {
        typ = node.typ.reduce()
        num := p.new_node_num(typ.size_allow_void())
        typ.kind = node.typ.kind.clone()
        typ.suffix = node.typ.suffix.clone()
        right = p.new_node(.mul, right, num)
        right.typ = typ.clone()
      } else if node.typ.is_int() && right.typ.is_ptr() {
        typ = right.typ.reduce()
        num := p.new_node_num(typ.size_allow_void())
        typ.kind = node.typ.kind.clone()
        typ.suffix = node.typ.suffix.clone()
        node = p.new_node(.mul, node, num)
        node.typ = typ.clone()
      } else if node.typ.is_int() && right.typ.is_int() {
        p.token_err('Either expression in a[b] should be pointer')
      } else {
        p.token_err('Both body and suffix are pointers in a[b] expression')
      }
      node = p.new_node(.add, node, right)
      node.typ = typ
      node = p.new_node(.deref, node, p.new_node_nothing())
      p.expect(']')
    } else if p.consume('(') {
      name := if node.kind == .gvar && node.typ.kind.last() == .func {
        node.name
      } else {
        ''
      }
      node.add_type()
      if node.typ.kind.last() != .func {
        if !node.typ.is_ptr() {
          p.token_err('Cannot call non-functional type')
        } else {
          mut typ := node.typ
          for typ.is_ptr() {
            typ = typ.reduce()
          }
          if typ.kind.last() != .func {
            p.token_err('Cannot call non-functional type')
          }
        }
      }
      func := node
      if p.consume(')') {
        node = p.new_node_call(0, name, p.new_node_nothing())
        node.right = func
      } else {
        args, num := p.args()
        p.expect(')')
        node = p.new_node_call(num, name, args)
        node.right = func
      }
      node.add_type()
      node.typ = func.typ
      for node.typ.is_ptr() {
        node.typ = node.typ.reduce()
      }
      node.typ = node.typ.reduce()
    } else if p.consume('.') {
      node.add_type()
      if node.typ.kind.last() != .strc {
        p.token_err('Expected struct type')
      }
      strc := (node.typ.strc.last()).val
      name := p.expect_ident()
      if !name in strc.content {
        p.token_err('There is no member named `$name`')
      }
      member := strc.content[name].val
      node = p.new_node(.add, node, p.new_node_num(member.offset))
      node.typ = member.typ.clone()
      node.typ.kind << Typekind.ptr
      node = p.new_node(.deref, node, p.new_node_nothing())
    } else if p.consume('->') {
      node.add_type()
      if !node.typ.is_ptr() || (node.typ.reduce()).kind.last() != .strc {
        p.token_err('Expected pointer/array of struct type')
      }
      strc := (node.typ.strc.last()).val
      name := p.expect_ident()
      if !name in strc.content {
        p.token_err('There is no member named `$name`')
      }
      member := strc.content[name].val
      node = p.new_node(.add, node, p.new_node_num(member.offset))
      node.typ = member.typ.clone()
      node.typ.kind << Typekind.ptr
      node = p.new_node(.deref, node, p.new_node_nothing())
    } else {
      return node
    }
  }
  return node
}

fn (p mut Parser) args() (&Node, int) {
  expr := p.assign()
  if p.consume(',') {
    args, num := p.args()
    return p.new_node(.args, expr, args), num+1
  }
  return p.new_node(.args, expr, p.new_node_nothing()), 1
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

  is_lvar, lvar, _ := p.find_lvar(name)
  if !is_lvar {
    p.token_err('`$name` is not declared yet')
  } else if lvar.is_type {
    p.token_err('`$name` is declared as type')
  }
  node := if lvar.is_global || lvar.typ.kind.last() == .func {
    p.new_node_gvar(lvar.offset, lvar.typ, name)
  } else if lvar.is_static {
    p.new_node_gvar(lvar.offset, lvar.typ, '$name\.$lvar.offset')
  } else {
    p.new_node_lvar(lvar.offset, lvar.typ)
  }
  return node
}

