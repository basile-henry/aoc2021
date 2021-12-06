.PHONY: watch run main

watch:
	watchexec -c -w "src" "zig run src/day$(day).zig"

run:
	zig run -O ReleaseSafe src/day$(day).zig

main:
	zig build-exe -O ReleaseSafe src/main.zig
