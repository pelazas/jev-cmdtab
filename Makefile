APP = JevCmdTab
BUNDLE = .build/$(APP).app
BIN = $(BUNDLE)/Contents/MacOS/$(APP)
SRCS = $(wildcard Sources/*.swift)
PLIST = Resources/Info.plist

.PHONY: app run clean

app: $(BIN)

$(BIN): $(SRCS) $(PLIST)
	mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	cp $(PLIST) $(BUNDLE)/Contents/Info.plist
	printf 'APPL????' > $(BUNDLE)/Contents/PkgInfo
	swiftc -parse-as-library -O \
		-framework AppKit -framework Carbon -framework ApplicationServices \
		-o $(BIN) $(SRCS)
	codesign --force --sign - --identifier com.pelazas.jevcmdtab $(BUNDLE)

run: app
	open $(BUNDLE)

clean:
	rm -rf .build
