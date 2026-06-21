CLANG_FORMAT_FILES = \
	'*.h' \
	'*.hpp' \
	'*.hpp.in' \
	'*.iig' \
	'*.mm' \
	'*.cpp' \
	':(exclude)vendor/**'

all: clang-format swift-format swiftlint

clang-format:
	git ls-files -z -- $(CLANG_FORMAT_FILES) | xargs -0 clang-format -i

swift-format:
	git ls-files -z -- '*.swift' | xargs -0 swift-format -i

swiftlint:
	swiftlint
