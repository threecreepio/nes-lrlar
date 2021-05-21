AS = ca65
CC = cc65
LD = ld65

.PHONY: clean

build: lrlar.nes

%.o: src/%.asm
	$(AS) -g --create-dep "$@.dep" --debug-info $< -o $@

lrlar.nes: layout main.o
	$(LD) --dbgfile $@.dbg -C $^ -o $@

clean:
	rm -f example.nes *.dep *.o *.dbg

include $(wildcard *.dep)
