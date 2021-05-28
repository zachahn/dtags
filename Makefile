.PHONY: all release

all:
	crystal build src/dtags.cr

release:
	crystal build src/dtags.cr --release
