.PHONY: test precommit help all
.DEFAULT_GOAL := help

install-tools:
	./scripts/install-tools.sh

fmt:
	./scripts/fmt.sh

test:
	./tests/run-all-tests.sh