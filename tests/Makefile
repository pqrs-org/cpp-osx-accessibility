all:
	@for d in `find * -type d`; do \
		if [ -f "$$d/CMakeLists.txt" ]; then \
			echo "[Test] $$d"; \
			make -C $$d || exit 1; \
		fi; \
	done
	@echo "[Test] swift"
	@make -C swift

clean:
	@for d in `find * -type d`; do \
		if [ -f "$$d/CMakeLists.txt" ]; then \
			make -C $$d clean; \
		fi; \
	done
	@make -C swift clean
