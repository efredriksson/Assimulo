.PHONY: build wheel build-dev-image build-manylinux-image test shell compile-deps check-meson.build build-dev wheel-portable wheel-cibw
DOCKER_IMAGE      := assimulo-dev
MANYLINUX_IMAGE   := assimulo-manylinux
MESON_BUILD_DIR   := builddir
PYTHON_VERSIONS   ?= 3.12
IN_DOCKER_IMG     := $(shell test -f /.dockerenv && echo 1 || echo 0)

MESON_SETUP_ARGS := -Dsundials_prefix=/usr -Dsuperlu_prefix=/usr -Dopenmp=true
PIP_SETUP_ARGS   := $(addprefix -Csetup-args=,$(MESON_SETUP_ARGS))

define _run
	@if [ $(IN_DOCKER_IMG) -eq 1 ]; then \
		$(1);\
	else \
		docker run \
		--rm $(2) \
		-v $(CURDIR):/src \
		${DOCKER_IMAGE} \
		$(1); \
	fi
endef

define _run_with_venv
	$(call _run, bash -c '. .venv/bin/activate && $(1)')
endef

build-dev-image:
	docker build -t ${DOCKER_IMAGE} .

build-manylinux-image:
	docker build -f Dockerfile.manylinux -t ${MANYLINUX_IMAGE} .

.venv: requirements.lock
	$(call _run, python3 -m venv .venv)
	$(call _run_with_venv, pip install -r requirements.lock)
	$(call _run, touch .venv)

build: .venv
	$(call _run_with_venv, pip install . -v $(PIP_SETUP_ARGS))

wheel: .venv
	$(call _run_with_venv, pip wheel . --no-deps $(PIP_SETUP_ARGS) -w dist)

build-dev: .venv
	$(call _run_with_venv, pip install --no-build-isolation -e . -v -Cbuild-dir=$(MESON_BUILD_DIR) $(PIP_SETUP_ARGS))

test: .venv
	$(call _run_with_venv, pytest)

shell:
	$(call _run, /bin/bash, -it)

check-meson.build: .venv
	$(call _run_with_venv, meson setup $(MESON_BUILD_DIR) $(MESON_SETUP_ARGS) --wipe)

compile-deps:
	$(call _run, python3 -m venv .venv)
	$(call _run_with_venv, pip install pip-tools)
	$(call _run_with_venv, pip-compile --extra=dev --output-file=requirements.lock pyproject.toml)

wheel-cibw:
	pip install cibuildwheel
	cibuildwheel --platform linux --output-dir dist/

wheel-portable:
	mkdir -p dist
	docker run --rm -v $(CURDIR):/src $(MANYLINUX_IMAGE) bash -c '\
		mkdir -p /src/dist/raw; \
		for pyver in $(PYTHON_VERSIONS); do \
			pydir="cp$${pyver//./}-cp$${pyver//./}"; \
			/opt/python/$$pydir/bin/pip wheel /src --no-deps $(PIP_SETUP_ARGS) -w /src/dist/raw; \
		done; \
		for whl in /src/dist/raw/assimulo-*.whl; do \
			auditwheel repair $$whl --plat manylinux_2_27_x86_64 -w /src/dist; \
		done'
