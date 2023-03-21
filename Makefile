directtemp:
	clang -arch x86_64 -fobjc-arc -framework Foundation -framework IOKit directtemp.m -o /private/tmp/$@_x86_64
	clang -arch arm64 -fobjc-arc -framework Foundation -framework IOKit directtemp.m -o /private/tmp/$@_arm64
	lipo -create /private/tmp/directtemp_x86_64 /private/tmp/directtemp_arm64 -output directtemp	
clean:
	rm directtemp
	
run: directtemp
	./directtemp