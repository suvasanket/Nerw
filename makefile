APP=Zabb
SOURCES=Sources/Zabb/*.swift

main:
	swiftc -o $(APP) $(SOURCES) -framework Cocoa -framework Carbon

clean:
	rm -f $(APP)

run: main
	./$(APP)
