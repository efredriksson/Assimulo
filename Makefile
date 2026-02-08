.PHONY: build wheel build-dev-image test shell
DOCKER_IMAGE := assimulo-dev
IN_DOCKER_IMG := $(shell test -f /.dockerenv && echo 1 || echo 0)

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

build-dev-image:
	docker build -t ${DOCKER_IMAGE} .

.venv: requirements.lock
	$(call _run, python3 -m venv .venv)
	$(call _run, .venv/bin/pip install -r requirements.lock)
	$(call _run, touch .venv)

build: .venv
	$(call _run, .venv/bin/pip install . \
	-v -v -v \
	-Csetup-args=-Dsundials_prefix=/usr \
	-Csetup-args=-Dsuperlu_prefix=/usr \
	-Csetup-args=-Dopenmp=true)

wheel: .venv
	$(call _run, .venv/bin/pip wheel . \
	-v -v -v \
	--no-deps \
	-Csetup-args=-Dsundials_prefix=/usr \
	-Csetup-args=-Dsuperlu_prefix=/usr \
	-Csetup-args=-Dopenmp=true \
	-w dist)

test:
	$(call _run, .venv/bin/pytest)

shell:
	$(call _run, /bin/bash, -it)
