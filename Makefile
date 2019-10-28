vcc:
	v -o vcc ./src

test: vcc
	v run test.vsh
	make clean

clean:
	rm -f vcc tmp*

.PHONY: test clean
