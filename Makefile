stuff: stuff.o
	cc $< -o $@

stuff.o: stuff.ll
	llc -O0 -o $@ -filetype=obj $<

stuff.ll: samples/stuff.cke
	bundle exec bin/clarke $< > $@
