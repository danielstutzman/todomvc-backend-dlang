.PHONY: clean default

default: hello

clean:
	rm -f hello

hello:
	dmd hello.d -L/usr/lib/libpq.dylib
