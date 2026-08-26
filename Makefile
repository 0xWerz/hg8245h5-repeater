.PHONY: check third-party configure package clean

check:
	python3 -m unittest discover -s tests -v
	python3 -m py_compile tools/configure.py
	./scripts/check-tree.sh

third-party:
	./scripts/build-third-party.sh

configure:
	python3 tools/configure.py

package: configure
	mkdir -p dist
	tar -C build/stage -czf dist/hg8245h5-repeater.tar.gz .
	shasum -a 256 dist/hg8245h5-repeater.tar.gz > dist/hg8245h5-repeater.tar.gz.sha256

clean:
	@echo "Remove build/ and dist/ when you no longer need generated packages."
