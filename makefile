APP=Nerw
SOURCES=Sources/Nerw/*.swift

main:
	swiftc -o $(APP) $(SOURCES) -framework Cocoa -framework Carbon

clean:
	rm -f $(APP)

run: main
	./$(APP)
