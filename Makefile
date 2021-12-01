.PHONY: watch run

watch:
	watchexec -c -w "src" "zig run src/day$(day).zig"

run:
	zig run -Drelease-safe src/day$(day).zig
