test:
	zig build test --summary all

run:
	zig build run

run/release:
	zig build -Doptimize=ReleaseSafe run
