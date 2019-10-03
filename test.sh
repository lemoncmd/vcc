#!/bin/bash
try() {
  expected="$1"
  input="$2"

  ./vcc "$input" > tmp.s
  gcc -o tmp tmp.s
  ./tmp
  actual="$?"

  if [ "$actual" = "$expected" ]; then
    echo "$input => $actual"
  else
    echo "$input => $expected expected, but got $actual"
    exit 1
  fi
}

try 0 '0;'
try 42 '42;'
try 21 "5+20-4;"
try 41 " 12 + 34 - 5 ;"
try 47 '5+6*7;'
try 15 '5*(9-6);'
try 4 '(3+5)/2;'
try 7 '-3+10;'
try 7 '-3++10;'
try 7 '-3--10;'
try 12 '-(3+5)+20;'
try 30 '-3*+5*-2;'
try 1 '1+1==2;'
try 0 '1+1==3;'
try 1 '2>1;'
try 1 '43>=43;'
try 0 '(0<1)*2!=2;'
try 1 '1>2==3>=4;'
try 5 'foo=2;bar=4-1;foo=foo+bar;foo;'
try 3 'foo=2;return bar=4-1;foo=foo+bar;foo;'
try 2 'foo=bar=2;return foo;'
try 4 'returna = 3; _1_ = returna + 1; return _1_;'

echo OK
