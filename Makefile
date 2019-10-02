vcc:
	v -o vcc ./src

test: vcc
	./test.sh
	make clean

clean:
	rm -f vcc tmp*

.PHONY: test clean
