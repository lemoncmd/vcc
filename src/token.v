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
  if pos + len <= p.len && p.substr(pos, pos + len) == needle &&
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

    if pos + 2 <= p.len && p.substr(pos, pos + 2) == '//' {
      for p[pos] != `\n` || pos < p.len {
        pos++
      }
      continue
    }

    if pos + 2 <= p.len && p.substr(pos, pos + 2) == '/*' {
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

    if is_token_string(p, 'return', pos) {
      tokens << new_token(.reserved, 'return', line, lpos)
      pos += 6
      lpos += 6
      continue
    }

    if is_token_string(p, 'sizeof', pos) {
      tokens << new_token(.reserved, 'sizeof', line, lpos)
      pos += 6
      lpos += 6
      continue
    }

    if is_token_string(p, 'if', pos) {
      tokens << new_token(.reserved, 'if', line, lpos)
      pos += 2
      lpos += 2
      continue
    }

    if is_token_string(p, 'else', pos) {
      tokens << new_token(.reserved, 'else', line, lpos)
      pos += 4
      lpos += 4
      continue
    }

    if is_token_string(p, 'while', pos) {
      tokens << new_token(.reserved, 'while', line, lpos)
      pos += 5
      lpos += 5
      continue
    }

    if is_token_string(p, 'for', pos) {
      tokens << new_token(.reserved, 'for', line, lpos)
      pos += 3
      lpos += 3
      continue
    }

    if is_token_string(p, 'int', pos) {
      tokens << new_token(.reserved, 'int', line, lpos)
      pos += 3
      lpos += 3
      continue
    }

    if is_token_string(p, 'char', pos) {
      tokens << new_token(.reserved, 'char', line, lpos)
      pos += 4
      lpos += 4
      continue
    }

    if is_token_string(p, 'short', pos) {
      tokens << new_token(.reserved, 'short', line, lpos)
      pos += 5
      lpos += 5
      continue
    }

    if is_token_string(p, 'long', pos) {
      tokens << new_token(.reserved, 'long', line, lpos)
      pos += 4
      lpos += 4
      continue
    }

    if pos + 1 < p.len && (p.substr(pos, pos+2) in ['==', '!=', '>=', '<=', '++', '--']) {
      tokens << new_token(.reserved, p.substr(pos, pos+2), line, lpos)
      pos += 2
      lpos += 2
      continue
    }

    if p[pos] in [`+`, `-`, `*`, `/`, `(`, `)`, `<`, `>`, `;`, `=`, `{`, `}`, `,`, `&`, `[`, `]`, `%`, `!`, `|`, `^`, `~`] {
      tokens << new_token(.reserved, p[pos++].str(), line, lpos)
      lpos++
      continue
    }

    if p[pos] == `"` {
      pos++
      lpos++
      start_pos := pos
      for p[pos-1] == `\`` || p[pos] != `"` {
        pos++
        lpos++
        if p[pos] == `\n` {
          line++
          lpos=0
        }
      }
      tokens << new_token(.string, p.substr(start_pos, pos).replace('\\\n', ''), line, lpos)
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
      tokens << new_token(.num, p.substr(start_pos, pos), line, lpos)
      continue
    }

    if p[pos].is_letter() || p[pos] == `_` {
      start_pos := pos
      for pos < p.len && (p[pos].is_letter() || p[pos] == `_` || p[pos].is_digit()) {
        pos++
        lpos++
      }
      tokens << new_token(.ident, p.substr(start_pos, pos), line, lpos)
      continue
    }

    parse_err('$line:$lpos: Cannot tokenize')
  }

  tokens << new_token(.eof, '', line, lpos)
  return tokens
}

