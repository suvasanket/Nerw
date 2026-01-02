APP=Nerw
BUILD_DIR=.build/debug

main:
	swift build

clean:
	swift package reset
	rm -rf .build

run: main
	$(BUILD_DIR)/$(APP)
