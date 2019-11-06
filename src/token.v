module main

struct Tok {
  kind Token
  str string
  line int
  pos int
}

enum Token {
  eof
  ident
  reserved
  num
  string
}

fn new_token(token Token, s string, line, pos int) Tok {
  return Tok{token, s, line, pos}
}

fn is_token_string(p, needle string, pos int) bool {
  len := needle.len
  if pos + len <= p.len && p[pos..pos+len] == needle &&
     !p[pos + len].is_letter() && !p[pos + len].is_digit() && p[pos + len] != `_` {
    return true
  } else {
    return false
  }
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

    if pos + 2 <= p.len && p[pos..pos+2] == '//' {
      for p[pos] != `\n` || pos < p.len {
        pos++
      }
      continue
    }

    if pos + 2 <= p.len && p[pos..pos+2] == '/*' {
      pos += 3
      lpos += 3
      for pos < p.len && !(p[pos-1] == `*` && p[pos] == `/`) {
        pos++
        lpos++
        if p[pos] == `\n` {
          line++
          lpos = 0
        }
      }
      pos++
      line++
      continue
    }

    reserves := [
      '_Bool', '_Complex', '_Imaginary',
      'auto', 'break', 'case', 'char', 'const', 'continue', 'default', 'do',
      'double', 'else', 'enum', 'extern', 'float', 'for', 'goto', 'if',
      'inline', 'int', 'long', 'register', 'restrict', 'return', 'signed',
      'sizeof', 'short', 'static', 'struct', 'switch', 'typedef', 'union',
      'unsigned', 'void', 'volatile', 'while'
    ]

    for res in reserves {
      if is_token_string(p, res, pos) {
        tokens << new_token(.reserved, res, line, lpos)
        pos += res.len
        lpos += res.len
        goto cont
      }
    }

    if pos + 1 < p.len && (p[pos..pos+2] in ['==', '!=', '>=', '<=', '&&', '||', '++', '--', '->', '<<', '>>', '+=', '-=', '*=', '/=', '%=', '&=', '|=', '^=']) {
      tokens << new_token(.reserved, p[pos..pos+2], line, lpos)
      pos += 2
      lpos += 2
      continue
    }

    if p[pos] in [`+`, `-`, `*`, `/`, `(`, `)`, `<`, `>`, `;`, `=`, `{`, `}`, `,`, `&`, `[`, `]`, `%`, `!`, `|`, `^`, `~`, `?`, `:`, `.`] {
      tokens << new_token(.reserved, p[pos].str(), line, lpos)
      pos++
      lpos++
      continue
    }

    if p[pos] == `"` {
      pos++
      lpos++
      start_pos := pos
      for p[pos] != `"` {
        if p[pos] == `\\` {
          pos++
          lpos++
          if p[pos] == `\n` {
            line++
            lpos = 0
          }
        }
        pos++
        lpos++
        if p[pos] == `\n` {
          line++
          lpos = 0
        }
      }
      tokens << new_token(.string, p[start_pos..pos].replace('\\\n', ''), line, lpos)
      pos++
      lpos++
      continue
    }

    if p[pos].is_digit() {
      start_pos := pos
      for pos < p.len && p[pos].is_digit() {
        pos++
        lpos++
      }
      tokens << new_token(.num, p[start_pos..pos], line, lpos)
      continue
    }

    if p[pos].is_letter() || p[pos] == `_` {
      start_pos := pos
      for pos < p.len && (p[pos].is_letter() || p[pos] == `_` || p[pos].is_digit()) {
        pos++
        lpos++
      }
      tokens << new_token(.ident, p[start_pos..pos], line, lpos)
      continue
    }

    parse_err('$line:$lpos: Cannot tokenize')
cont:
  }

  tokens << new_token(.eof, '', line, lpos)
  return tokens
}

