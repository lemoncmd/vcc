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

    if pos + 5 < p.len && p.substr(pos, pos+6) == 'return' && 
       !p[pos+6].is_letter() && !p[pos+6].is_digit() && p[pos+6] != `_` {
      tokens << new_token(.reserved, 'return', line, lpos)
      pos += 6
      lpos += 6
      continue
    }

    if pos + 1 < p.len && p.substr(pos, pos+2) == 'if' && 
       !p[pos+2].is_letter() && !p[pos+2].is_digit() && p[pos+2] != `_` {
      tokens << new_token(.reserved, 'if', line, lpos)
      pos += 2
      lpos += 2
      continue
    }

    if pos + 3 < p.len && p.substr(pos, pos+4) == 'else' && 
       !p[pos+4].is_letter() && !p[pos+4].is_digit() && p[pos+4] != `_` {
      tokens << new_token(.reserved, 'else', line, lpos)
      pos += 4
      lpos += 4
      continue
    }

    if pos + 4 < p.len && p.substr(pos, pos+5) == 'while' && 
       !p[pos+5].is_letter() && !p[pos+5].is_digit() && p[pos+5] != `_` {
      tokens << new_token(.reserved, 'while', line, lpos)
      pos += 5
      lpos += 5
      continue
    }

    if pos + 2 < p.len && p.substr(pos, pos+3) == 'for' && 
       !p[pos+3].is_letter() && !p[pos+3].is_digit() && p[pos+3] != `_` {
      tokens << new_token(.reserved, 'for', line, lpos)
      pos += 3
      lpos += 3
      continue
    }

    if pos + 1 < p.len && p.substr(pos, pos+2) in ['==', '!=', '>=', '<='] {
      tokens << new_token(.reserved, p.substr(pos, pos+2), line, lpos)
      pos += 2
      lpos += 2
      continue
    }

    if p[pos] in [`+`, `-`, `*`, `/`, `(`, `)`, `<`, `>`, `;`, `=`, `{`, `}`] {
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

