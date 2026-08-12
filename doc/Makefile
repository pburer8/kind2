.PHONY: all doc html pdf clean distclean serve theme vendor-assets update

# `make doc` builds both output formats, matching the old Sphinx `make all` (html + pdf).
<<<<<<< HEAD
<<<<<<< HEAD
all: doc
<<<<<<< HEAD
<<<<<<< HEAD
doc: html pdf update
<<<<<<< HEAD
=======
all: doc update
=======
all: doc
>>>>>>> ffaa8272 (Remove some files)
doc: html pdf
>>>>>>> 2810cf4e (Partial Makefile update)
=======
>>>>>>> 40c9b7b5 (Added README generation and changed the site to be clearer)
=======
doc: html pdf
>>>>>>> b7017aa2 (Remove vendor code for build-at-runtime)
=======
doc: html pdf update
>>>>>>> b48c1094 (Updated READMEs and Makefile)

# Hextra is a git submodule (see .gitmodules), not vendored in this repo — this
# pulls it in automatically the first time you build after `git clone`.
theme: themes/hextra/layouts

themes/hextra/layouts:
	@if git rev-parse --git-dir > /dev/null 2>&1; then \
		echo "==> fetching theme (git submodule)"; \
		git submodule update --init --recursive; \
	else \
		echo "themes/hextra is missing and this isn't a git checkout, so it can't be"; \
		echo "fetched automatically. Either:"; \
		echo "  git clone --recurse-submodules <this-repo-url>"; \
		echo "or, if you already have a plain clone:"; \
		echo "  git submodule update --init --recursive"; \
		exit 1; \
	fi

<<<<<<< HEAD
<<<<<<< HEAD
update:
	@printf "Updating root README.md and LICENSE.md...\n"
	{ \
		printf '<!-- DO NOT EDIT, edit content/_index.md instead -->\n'; \
		cat content/header.md; \
		printf '\n'; \
		awk 'BEGIN{front=0} NR==1 && /^---$$/{front=1;next} front && /^title:/{title=$$0;sub(/^title:[[:space:]]*/,"",title);gsub(/^"|"$$/,"",title);next} front && /^---$$/{front=0;if(title!=""){print "# " title;print ""}next} !front{print}' content/_index.md | \
		sed -E 's|\{\{< relref "/([^"#]+)(#[^"]*)?" >\}\}|https://kind.cs.uiowa.edu/docs/main/user/\1/\2|g'; \
	} > ../README.md
	awk 'BEGIN{front=0} NR==1 && /^---$$/{front=1;next} front && /^title:[[:space:]]*/{title=$$0;sub(/^title:[[:space:]]*/,"",title);gsub(/^"|"$$/,"",title);next} front && /^---$$/{front=0;if(title!=""){print "# " title}next} !front{print}' content/license.md > ../LICENSE.md
	@printf '<!-- DO NOT EDIT, edit content/README.md instead -->\n' > README.md
	cat content/README.md >> README.md

=======
>>>>>>> b7017aa2 (Remove vendor code for build-at-runtime)
=======
update:
	# Generate the project README with CI links for Github
	echo '<!-- DO NOT EDIT, see doc/README.md for details -->\n' > ../README.md
	cat content/header.md >> ../README.md
	cat content/home.md >> ../README.md
	# Replace internal references with explicit ones to render README on Github
	sed -E -i 's/:ref:`(.*)<(.*)>`/`\1<${doc_root}\2\.html>`_/g' ../README.md
	# Replace include directives with the file contents, as the
	# directives are not currently supported/rendered on Github.
	# The source/ directory is where files included in
	# this manner are expected to reside.
	#     https://unix.stackexchange.com/a/128797/248178
	sed -i '/\.\. include:: \(.*\)/{s//source\/\1/;s/'\''/&\\&&/g;s/.*/cat<'"'&'/e}" ../README.md
	# Generate the documentation README
	echo '<!-- DO NOT EDIT, edit content/README.md instead -->\n' > README.md
	cat content/README.md >> README.md
	sed -i '/\.\. include:: \(.*\)/{s//source\/\1/;s/'\''/&\\&&/g;s/.*/cat<'"'&'/e}" README.md
	cp content/docs/license.md ../LICENSE.md

>>>>>>> b48c1094 (Updated READMEs and Makefile)
# KaTeX (math) and FlexSearch (search) are fetched via npm into assets/vendor/
# on demand, not committed — see fetch-vendor-assets.sh. This avoids relying
# on cdn.jsdelivr.net at Hugo build time without checking binary assets into git.
vendor-assets: assets/vendor/katex/dist/katex.min.css

assets/vendor/katex/dist/katex.min.css assets/vendor/flexsearch/dist/flexsearch.bundle.min.js &: fetch-vendor-assets.sh
	./fetch-vendor-assets.sh

html: theme vendor-assets
	hugo --minify

<<<<<<< HEAD
VENV := pdf-tools/venv

venv: $(VENV)/bin/activate

$(VENV)/bin/activate: pdf-tools/requirements.txt
	@if ! python3 -m venv $(VENV); then \
		rm -rf $(VENV); \
		echo; \
		echo "ERROR: could not create a Python virtual environment at $(VENV)."; \
		echo "This system may restrict or disallow venv creation (e.g. a"; \
		echo "locked-down Python, or a missing python3-venv package)."; \
		echo; \
		echo "Install the PDF dependencies manually instead, then tell make"; \
		echo "to use that interpreter directly instead of a venv:"; \
		echo "  pip install -r pdf-tools/requirements.txt --break-system-packages"; \
		echo "  PYTHON=python3 make pdf"; \
		echo; \
		exit 1; \
	fi
	$(VENV)/bin/pip install --quiet --upgrade pip
	$(VENV)/bin/pip install --quiet -r pdf-tools/requirements.txt
	touch $(VENV)/bin/activate

# If PYTHON is set explicitly (env var or `make PYTHON=... pdf`), use it
# directly and skip venv creation altogether — this is the manual-install
# escape hatch referenced in the error message above.
ifneq ($(filter command line environment,$(origin PYTHON)),)
pdf: html
	SKIP_HUGO_BUILD=1 PYTHON=$(PYTHON) ./pdf-tools/build_pdf.sh
else
pdf: html venv
	SKIP_HUGO_BUILD=1 PYTHON=$(VENV)/bin/python3 ./pdf-tools/build_pdf.sh
endif

<<<<<<< HEAD
<<<<<<< HEAD
serve: theme vendor-assets
=======
=======
update:
	echo '<!-- DO NOT EDIT, see doc/usr/README.rst for details -->\n' > ../README.md
	cat content/header.md >> ../README.md
	cat content/home.md >> ../README.md
	# Replace internal references with explicit ones to render README on Github
	sed -E -i 's/:ref:`(.*)<(.*)>`/`\1<${doc_root}\2\.html>`_/g' ../README.md
	# Replace include directives with the file contents, as the
	# directives are not currently supported/rendered on Github.
	# The source/ directory is where files included in
	# this manner are expected to reside.
	#     https://unix.stackexchange.com/a/128797/248178
	sed -i '/\.\. include:: \(.*\)/{s//source\/\1/;s/'\''/&\\&&/g;s/.*/cat<'"'&'/e}" ../README.md
	# Generate the documentation README
	echo '<!-- DO NOT EDIT, edit content/README.md instead -->\n' > README.md
	cat content/README.md >> README.md
	sed -i '/\.\. include:: \(.*\)/{s//source\/\1/;s/'\''/&\\&&/g;s/.*/cat<'"'&'/e}" README.md

	cp content/docs/license.md ../../LICENSE.md

>>>>>>> 40c9b7b5 (Added README generation and changed the site to be clearer)
serve:
>>>>>>> ffaa8272 (Remove some files)
=======
pdf: html
	SKIP_HUGO_BUILD=1 PYTHON=$(VENV)/bin/python3 ./pdf-tools/build_pdf.sh

serve: theme vendor-assets
>>>>>>> b7017aa2 (Remove vendor code for build-at-runtime)
	hugo server -D

clean:
	rm -rf public resources/_gen print/all-docs.html print/*.pdf

distclean: clean
<<<<<<< HEAD
	rm -rf $(VENV) assets/vendor assets/css/fonts/
=======
	rm -rf $(VENV) assets/vendor
>>>>>>> b7017aa2 (Remove vendor code for build-at-runtime)
