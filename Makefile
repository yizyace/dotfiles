.PHONY: test test-verbose

test:
	bats tests/

test-verbose:
	bats --verbose-run tests/
