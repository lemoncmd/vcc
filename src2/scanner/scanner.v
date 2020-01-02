module scanner

import (
  src2.token
)

pub struct Scanner {
mut:
  program string
  pos int
  line int
  lpos int
}

fn (s &Scanner) error(str string) {
  program := s.program.split_into_lines()[s.line-1]
  here := [' '].repeat(s.lpos).join('')
  println('$s.line:$s.lpos: $str\n$program\n$here^here')
  exit(1)
}

fn (s &Scanner) is_token_string(needle string) bool {
  len := needle.len
  read := s.read(len)
  after := if s.program.len > s.pos + len { s.program[s.pos+len] } else { `\0` }
  return read == needle && !after.is_letter() && !after.is_digit() && after != `_`
}

fn hex_to_num(b byte) int {
  if b >= `0` && b <= `9` {
    return int(b - `0`)
  }
  if b >= `A` && b <= `F` {
    return int(b - `A` + 10)
  }
  return int(b - `a` + 10)
}

fn (s mut Scanner) next() {
  s.pos++
  s.lpos++
}

fn (s mut Scanner) skip(num int) {
  s.pos += num
  s.lpos += num
}

fn (s mut Scanner) new_line() {
  s.line++
  s.lpos = 0
}

fn (s &Scanner) read(num int) string {
  if s.pos + num <= s.program.len {
    return s.program[s.pos..s.pos+num]
  }
  return ''
}

fn (s mut Scanner) skip_delimiter() {
  for {
    c := s.program[s.pos]
    len := s.program.len

    if c == `\n` {
      s.next()
      s.new_line()
      continue
    }

    if c.is_space() {
      s.next()
      continue
    }

    if c == `#` { //this is a hack for preprocessed gcc code
      s.next()
      for s.pos < len && !(s.program[s.pos-1] != `\\` && s.program[s.pos] == `\n`) {
        s.next()
      }
      continue
    }

    match s.read(2) {
      '//' {
        s.next()
        for s.pos < len && !(s.program[s.pos-1] != `\\` && s.program[s.pos] == `\n`) {
          s.next()
        }
        continue
      }
      '/*' {
        s.skip(3)
        for s.pos < len && !(s.program[s.pos-1] == `*` && s.program[s.pos] == `/`) {
          s.next()
          if s.program[s.pos] == `\n` {
            s.new_line()
          }
        }
        s.next()
        continue
      }
      '\\\n' {
        s.skip(2)
        s.new_line()
        continue
      }
      else {
        break
      }
    }
  }
}

fn (s &Scanner) create_token(kind token.Kind, str string) token.Token {
  return token.Token{
    kind: kind
    str:  str
    line: s.line
    pos:  s.lpos
  }
}

fn (s &Scanner) end_of_file() token.Token {
  return s.create_token(.eof, '')
}

pub fn (s mut Scanner) scan() token.Token {
  //s.skip_delimiter()

  for i, res in token.reserves {
    if s.is_token_string(res) {
      kind := token.Kind(i + int(token.Kind.k_bool))
      token := s.create_token(kind, res)
      s.skip(res.len)
      return token
    }
  }

  mut skips := 3
  defer {
    s.skip(skips)
  }
  match s.read(3) {
    '<<=' { return s.create_token(.ls_assign, '<<=') }
    '>>=' { return s.create_token(.rs_assign, '>>=') }
    '...' { return s.create_token(.tridot, '...') }
    else {}
  }

  skips = 2
  match s.read(2) {
    '==' { return s.create_token(.eq, '==') }
    '!=' { return s.create_token(.ne, '!=') }
    '>=' { return s.create_token(.ge, '>=') }
    '<=' { return s.create_token(.le, '<=') }
    '&&' { return s.create_token(.land, '&&') }
    '||' { return s.create_token(.lor, '||') }
    '++' { return s.create_token(.inc, '++') }
    '--' { return s.create_token(.dec, '--') }
    '->' { return s.create_token(.arrow, '->') }
    '<<' { return s.create_token(.lshift, '<<') }
    '>>' { return s.create_token(.rshift, '>>') }
    '+=' { return s.create_token(.pl_assign, '+=') }
    '-=' { return s.create_token(.mn_assign, '-=') }
    '*=' { return s.create_token(.ml_assign, '*=') }
    '/=' { return s.create_token(.dv_assign, '/=') }
    '%=' { return s.create_token(.md_assign, '%=') }
    '&=' { return s.create_token(.an_assign, '&=') }
    '|=' { return s.create_token(.or_assign, '|=') }
    '^=' { return s.create_token(.xo_assign, '^=') }
    else {}
  }

  skips = 1
  c := s.program[s.pos]
  match c {
    `+` { return s.create_token(.plus, c.str()) }
    `-` { return s.create_token(.minus, c.str()) }
    `*` { return s.create_token(.mul, c.str()) }
    `/` { return s.create_token(.div, c.str()) }
    `%` { return s.create_token(.mod, c.str()) }
    `^` { return s.create_token(.xor, c.str()) }
    `|` { return s.create_token(.aor, c.str()) }
    `&` { return s.create_token(.aand, c.str()) }
    `~` { return s.create_token(.anot, c.str()) }
    `!` { return s.create_token(.lnot, c.str()) }
    `>` { return s.create_token(.gt, c.str()) }
    `<` { return s.create_token(.lt, c.str()) }
    `,` { return s.create_token(.comma, c.str()) }
    `:` { return s.create_token(.colon, c.str()) }
    `.` { return s.create_token(.dot, c.str()) }
    `;` { return s.create_token(.semi, c.str()) }
    `?` { return s.create_token(.question, c.str()) }
    `=` { return s.create_token(.assign, c.str()) }
    `(` { return s.create_token(.lpar, c.str()) }
    `)` { return s.create_token(.rpar, c.str()) }
    `{` { return s.create_token(.lsbr, c.str()) }
    `}` { return s.create_token(.rsbr, c.str()) }
    `[` { return s.create_token(.lcbr, c.str()) }
    `]` { return s.create_token(.rcbr, c.str()) }
    `"` {
      skips = 0
      return s.scan_string()
    }
    `'` {
      skips = 0
      return s.scan_char()
    }
    else {
      skips = 0
      if c.is_digit() {
        return s.scan_number()
      }
      if c.is_letter() || c == `_` {
        return s.scan_ident()
      }
    }
  }
  s.error('Cannot tokenize')
  return s.end_of_file()
}

fn (s mut Scanner) scan_string() token.Token {
  s.next()
  start_pos := s.pos
  for s.program[s.pos] != `"` {
    if s.program[s.pos] == `\\` {
      s.next()
      if s.program[s.pos] == `\n` {
        s.new_line()
      }
    }
    s.next()
    if s.program[s.pos] == `\n` {
      s.new_line()
    }
  }
  s.next()
  return s.create_token(.str, s.program[start_pos..s.pos-1].replace('\\\n', ''))
}

fn (s mut Scanner) scan_char() token.Token {
  s.skip(2)
  mut num := 0
  if s.program[s.pos-1] == `\\` {
    c := s.program[s.pos]
    is_hex := c == `x`
    is_oct := c.is_oct_digit()

    num = match s.program[s.pos] {
      `a` {7}
      `b` {8}
      `f` {12}
      `n` {10}
      `r` {13}
      `t` {9}
      `v` {11}
      `x`, `0`, `1`, `2`, `3`, `4`, `5`, `6`, `7` {0}
      else {int(c)}
    }

    if is_hex {
      s.next()
      if !s.program[s.pos].is_hex_digit() { s.error('Expected hex digit') }
      num = hex_to_num(s.program[s.pos])
      if s.program[s.pos+1] != `'` {
        s.next()
        if !s.program[s.pos].is_hex_digit() { s.error('Expected hex digit') }
        num = 16*num + hex_to_num(s.program[s.pos])
      }
      if num > 127 {num -= 256}
    }
    if is_oct {
      num = int(s.program[s.pos] - `0`)
      if s.program[s.pos+1] != `'` {
        s.next()
        if !s.program[s.pos].is_oct_digit() { s.error('Expected oct digit') }
        num = 8*num + int(s.program[s.pos] - `0`)
        if s.program[s.pos+1] != `'` {
          s.next()
          if !s.program[s.pos].is_oct_digit() { s.error('Expected oct digit') }
          num = 8*num + int(s.program[s.pos] - `0`)
        }
      }
      if num > 255 { s.error('Octal out of range') }
      if num > 127 { num -= 256 }
    }
    s.next()
  } else {
    num = int(s.program[s.pos-1])
  }
  if s.program[s.pos] != `'` {
    got := s.program[s.pos].str()
    s.error('Expected \' but got $got')
  }
  s.next()
  return s.create_token(.num, num.str())
}

fn (s mut Scanner) scan_number() token.Token {
  start_pos := s.pos
  len := s.program.len
  mut is_octal := false
  if s.program[s.pos] == `0` {
    s.next()
    if s.program[s.pos] == `x` {
      s.next()
      for s.pos < len && s.program[s.pos].is_hex_digit() {
        s.next()
      }
    } else if s.program[s.pos].is_oct_digit() {
      is_octal = true
      for s.pos < len && s.program[s.pos].is_oct_digit() {
        s.next()
      }
    }
  } else {
    for s.pos < len && s.program[s.pos].is_digit() {
      s.next()
    }
  }
  return s.create_token(.num, if is_octal {'0o'} else {''} + s.program[start_pos..s.pos])
}

fn (s mut Scanner) scan_ident() token.Token {
  start_pos := s.pos
  for s.pos < s.program.len && (s.program[s.pos].is_letter() || s.program[s.pos] == `_` || s.program[s.pos].is_digit()) {
    s.next()
  }
  return s.create_token(.ident, s.program[start_pos..s.pos])
}
