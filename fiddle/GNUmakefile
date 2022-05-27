# This GNU makefile exists primarily to simplify/speed up development
# from emacs. It is not part of the canonical build process.
default: fiddle

fiddle_module_js := fiddle-module.js
fiddle_module_wasm := fiddle-module.wasm
fiddle_generated := $(fiddle_module_js) $(fiddle_module_wasm)
pikchr_c := ../pikchr.c

clean:
	rm -f $(fiddle_generated)
disclean: clean

ifneq (,$(wildcard /home/stephan))
  emcc_opt ?= -O0
else
  emcc_opt ?= -Oz
endif

$(pikchr_c):
	$(MAKE) -C ..

$(fiddle_module_js): $(pikchr_c) GNUmakefile
	emcc -o $@ $(emcc_opt) --no-entry \
        -sEXPORTED_RUNTIME_METHODS=cwrap \
        -sEXPORTED_FUNCTIONS=_pikchr $(pikchr_c) \
        -sENVIRONMENT=web \
        -sMODULARIZE \
        -sEXPORT_NAME=initPikchrModule \

fiddle: $(fiddle_module_js)

fiddle_files = emscripten.css fiddle.html \
             fiddle.js fiddle-module.js \
             fiddle-module.wasm fiddle-worker.js

# fiddle_remote is the remote destination for the fiddle app. It
# must be a [user@]HOST:/path for rsync.
# Note that the target "should probably" contain a symlink of
# index.html -> fiddle.html.
fiddle_remote ?=
ifeq (,$(fiddle_remote))
ifneq (,$(wildcard /home/stephan))
  fiddle_remote = wh2:www/wh/pikchr/.
else ifneq (,$(wildcard /home/drh))
  #fiddle_remote = if appropriate, add that user@host:/path here
endif
endif

push-fiddle: $(fiddle_files)
	@if [ x = "x$(fiddle_remote)" ]; then \
		echo "fiddle_remote must be a [user@]HOST:/path for rsync"; \
		exit 1; \
	fi
	rsync -va $(fiddle_files) $(fiddle_remote)
