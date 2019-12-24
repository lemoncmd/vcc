# VCC - The C Compiler in V

This is a toy C compiler written in V.  
This compiler is based on [chibicc](https://github.com/rui314/chibicc) by Rui Ueyama.  
This is the first compiler I have made.

The main object of this compiler is to compile The V Programming Language and compile itself by produced V binary.

Document by Rui Ueyama(Japanese): https://sigbus.info/compilerbook  
My blog(Japanese): https://blog.anzu.tech/post/vcc

## Usage
Please make sure that the V compiler is installed on your terminal.  
The V Programming Language: https://vlang.io

To build VCC, run the following command
```sh
v -o vcc ./src
```
or just type
```sh
make
```

To compile C source code,
```sh
./vcc foobar.c > foobar.s
gcc -o foobar foobar.s
```

## Key Features of VCC
- All the operators in C are implemented
- `extern` and global variables/prototype declaration supported
- You can declare variables in `for` statements! Yay!
- Structs and Unions are supported

## and WIPs, you know
- Preprocessor
- Initialization
- Float
- Enum
- Compound literal, it's well used in V

## Reference
Special thanks to [Rui Ueyama](https://twitter.com/rui314)
