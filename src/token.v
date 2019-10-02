module main

struct Tok {
  kind Token
  str string
  line int
  pos int
}

enum Token {
  eof
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

    if p[pos] in [`+`, `-`, `*`, `/`, `(`, `)`] {
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

    parse_err('$line:$lpos: Cannot tokenize')
  }

  tokens << new_token(.eof, '', line, lpos)
  return tokens
}

