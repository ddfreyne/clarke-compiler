stuff: stuff.o
	cc $< -o $@

stuff.o: stuff.ll
	llc -O0 -o $@ -filetype=obj $<

stuff.ll: test.rb
	bundle exec ruby $< > $@
