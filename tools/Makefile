CFLAGS ?= -O2 -march=native -pthread -Wall -Wextra

knobbench: knobbench.c
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f knobbench

.PHONY: clean
