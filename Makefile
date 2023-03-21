directtemp:
	clang -fobjc-arc -framework Foundation -framework IOKit directtemp.m -o $@
	
clean:
	rm directtemp
	
run: directtemp
	./directtemp