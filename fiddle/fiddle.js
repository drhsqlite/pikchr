/*
  2022-05-20

  The author disclaims copyright to this source code.  In place of a
  legal notice, here is a blessing:

  *   May you do good and not evil.
  *   May you find forgiveness for yourself and forgive others.
  *   May you share freely, never taking more than you give.

  ***********************************************************************

  This is the main entry point for the pikchr fiddle app. It sets up the
  various UI bits, loads a Worker for the db connection, and manages the
  communication between the UI and worker.
*/
(function(){
    'use strict';

    /* Recall that the 'self' symbol, except where locally
       overwritten, refers to the global window or worker object. */

    /**
       The PikchrFiddle object is intended to be the primary
       app-level object for the main-thread side of the sqlite
       fiddle application. It uses a worker thread to load the
       sqlite WASM module and communicate with it.
    */
    const PF/*local convenience alias*/
    = window.PikchrFiddle/*canonical name*/ = {
        /* Config options. */
        config: {
            /* If true, PikchrFiddle.echo() will echo its output to
               the console, in addition to its normal output widget.
               That slows it down but is useful for testing. */
            echoToConsole: false,
            /* If true, display input/output areas side-by-side. */
            sideBySide: true,
            /* If true, swap positions of the input/output areas. */
            swapInOut: true,
            /* If true, the SVG is allowed to resize to fit the
               parent content area, else the parent is resized to
               fit the rendered SVG. */
            renderAutoScale: false
        },
        renderMode: 'html'/*one of: 'text','html'*/,
        _msgMap: {},
        /** Adds a worker message handler for messages of the given
            type. */
        addMsgHandler: function f(type,callback){
            if(Array.isArray(type)){
                type.forEach((t)=>this.addMsgHandler(t, callback));
                return this;
            }
            (this._msgMap.hasOwnProperty(type)
             ? this._msgMap[type]
             : (this._msgMap[type] = [])).push(callback);
            return this;
        },
        /** Given a worker message, runs all handlers for msg.type. */
        runMsgHandlers: function(msg){
            const list = (this._msgMap.hasOwnProperty(msg.type)
                          ? this._msgMap[msg.type] : false);
            if(!list){
                console.warn("No handlers found for message type:",msg);
                return false;
            }
            list.forEach((f)=>f(msg));
            return true;
        },
        /** Removes all message handlers for the given message type. */
        clearMsgHandlers: function(type){
            delete this._msgMap[type];
            return this;
        },
        /* Posts a message in the form {type, data} to the db worker. Returns this. */
        wMsg: function(type,data){
            this.worker.postMessage({type, data});
            return this;
        }
    };

    PF.worker = new Worker('fiddle-worker.js');
    PF.worker.onmessage = (ev)=>PF.runMsgHandlers(ev.data);
    PF.addMsgHandler('stdout', console.log.bind(console));
    PF.addMsgHandler('stderr', console.error.bind(console));

    /* querySelectorAll() proxy */
    const EAll = function(/*[element=document,] cssSelector*/){
        return (arguments.length>1 ? arguments[0] : document)
            .querySelectorAll(arguments[arguments.length-1]);
    };
    /* querySelector() proxy */
    const E = function(/*[element=document,] cssSelector*/){
        return (arguments.length>1 ? arguments[0] : document)
            .querySelector(arguments[arguments.length-1]);
    };

    /** Handles status updates from the Module object. */
    PF.addMsgHandler('module', function f(ev){
        ev = ev.data;
        if('status'!==ev.type){
            console.warn("Unexpected module-type message:",ev);
            return;
        }
        if(!f.ui){
            f.ui = {
                status: E('#module-status'),
                progress: E('#module-progress'),
                spinner: E('#module-spinner')
            };
        }
        const msg = ev.data;
        if(f.ui.progres){
            progress.value = msg.step;
            progress.max = msg.step + 1/*we don't know how many steps to expect*/;
        }
        if(1==msg.step){
            f.ui.progress.classList.remove('hidden');
            f.ui.spinner.classList.remove('hidden');
        }
        if(msg.text){
            f.ui.status.classList.remove('hidden');
            f.ui.status.innerText = msg.text;
        }else{
            if(f.ui.progress){
                f.ui.progress.remove();
                f.ui.spinner.remove();
                delete f.ui.progress;
                delete f.ui.spinner;
            }
            f.ui.status.classList.add('hidden');
            /* The module can post messages about fatal problems,
               e.g. an exit() being triggered or assertion failure,
               after the last "load" message has arrived, so
               leave f.ui.status and message listener intact. */
        }
    });

    /**
       The 'fiddle-ready' event is fired (with no payload) when the
       wasm module has finished loading. Interestingly, that happens
       _before_ the final module:status event */
    PF.addMsgHandler('fiddle-ready', function(){
        PF.clearMsgHandlers('fiddle-ready');
        self.onPFLoaded();
    });

    /**
       Performs all app initialization which must wait until after the
       worker module is loaded. This function removes itself when it's
       called.
    */
    self.onPFLoaded = function(){
        delete this.onPFLoaded;
        // Unhide all elements which start out hidden
        EAll('.initially-hidden').forEach((e)=>e.classList.remove('initially-hidden'));
        const taInput = E('#input');
        const btnClearIn = E('#btn-clear');
        btnClearIn.addEventListener('click',function(){
            taInput.value = '';
        },false);
        // Ctrl-enter and shift-enter both run the current SQL.
        taInput.addEventListener('keydown',function(ev){
            if((ev.ctrlKey || ev.shiftKey) && 13 === ev.keyCode){
                ev.preventDefault();
                ev.stopPropagation();
                btnRender.click();
            }
        }, false);
        const taOutput = E('#output');
        const btnRender = E('#btn-render');
        btnRender.addEventListener('click',function(ev){
            let text;
            ev.preventDefault();
            if(taInput.selectionStart<taInput.selectionEnd){
                text = taInput.value.substring(taInput.selectionStart,taInput.selectionEnd).trim();
            }else{
                text = taInput.value.trim();
            }
            if(text) PF.render(text);
        },false);

        /** To be called immediately before work is sent to the
            worker. Updates some UI elements. The 'working'/'end'
            event will apply the inverse, undoing the bits this
            function does. This impl is not in the 'working'/'start'
            event handler because that event is given to us
            asynchronously _after_ we need to have performed this
            work.
        */
        const preStartWork = function f(){
            if(!f._){
                const title = E('title');
                f._ = {
                    btnLabel: btnRender.innerText,
                    pageTitle: title,
                    pageTitleOrig: title.innerText
                };
            }
            //f._.pageTitle.innerText = "[working...] "+f._.pageTitleOrig;
            btnRender.setAttribute('disabled','disabled');
        };

        /**
           Submits the current input text to pikchr and renders the
           result. */
        PF.render = function f(txt){
            preStartWork();
            this.wMsg('pikchr',txt);
        };

        const eOut = E('#pikchr-output');
        const eOutWrapper = E('#pikchr-output-wrapper');
        PF.addMsgHandler('pikchr', function(ev){
            const m = ev.data;
            eOut.classList[m.isError ? 'add' : 'remove']('error');
            eOut.dataset.pikchr = m.pikchr;
            let content;
            let sz;
            switch(PF.renderMode){
                case 'text':
                    content = '<textarea>'+m.result+'</textarea>';
                    eOut.classList.add('text');
                    eOutWrapper.classList.add('text');
                    break;
                default:
                    content = m.result;
                    eOut.classList.remove('text');
                    eOutWrapper.classList.remove('text');
                    break;
            }
            eOut.innerHTML = content;
            let vw = null, vh = null;
            if(!PF.config.renderAutoScale
               && !m.isError && 'html'===PF.renderMode){
                const svg = E(eOut,':scope > svg');
                const vb = svg ? svg.getAttribute('viewBox').split(' ') : false;
                if(vb && 4===vb.length){
                    vw = (+vb[2] + 10)+'px';
                    vh = (+vb[3] + 10)+'px';
                }else if(svg){
                    console.warn("SVG element is missing viewBox attribute.");
                }
            }
            eOut.style.width = vw;
            eOut.style.height = vh;
        });

        E('#btn-render-mode').addEventListener('click',function(){
            let mode = PF.renderMode;
            const modes = ['text','html'];
            let ndx = modes.indexOf(mode) + 1;
            if(ndx>=modes.length) ndx = 0;
            PF.renderMode = modes[ndx];
            if(eOut.dataset.pikchr){
                PF.render(eOut.dataset.pikchr);
            }
        });

        PF.addMsgHandler('working',function f(ev){
            switch(ev.data){
                case 'start': /* See notes in preStartWork(). */; return;
                case 'end':
                    //preStartWork._.pageTitle.innerText = preStartWork._.pageTitleOrig;
                    btnRender.innerText = preStartWork._.btnLabel;
                    btnRender.removeAttribute('disabled');
                    return;
            }
            console.warn("Unhandled 'working' event:",ev.data);
        });

        /* For each checkbox with data-csstgt, set up a handler which
           toggles the given CSS class on the element matching
           E(data-csstgt). */
        EAll('input[type=checkbox][data-csstgt]')
            .forEach(function(e){
                const tgt = E(e.dataset.csstgt);
                const cssClass = e.dataset.cssclass || 'error';
                e.checked = tgt.classList.contains(cssClass);
                e.addEventListener('change', function(){
                    tgt.classList[
                        this.checked ? 'add' : 'remove'
                    ](cssClass)
                }, false);
            });
        /* For each checkbox with data-config=X, set up a binding to
           PF.config[X]. These must be set up AFTER data-csstgt
           checkboxes so that those two states can be synced properly. */
        EAll('input[type=checkbox][data-config]')
            .forEach(function(e){
                const confVal = !!PF.config[e.dataset.config];
                if(e.checked !== confVal){
                    /* Ensure that data-csstgt mappings (if any) get
                       synced properly. */
                    e.checked = confVal;
                    e.dispatchEvent(new Event('change'));
                }
                e.addEventListener('change', function(){
                    PF.config[this.dataset.config] = this.checked;
                }, false);
            });
        E('#opt-cb-autoscale').addEventListener('change',function(){
            /* PF.config.renderAutoScale was set by the data-config
               event handler. */
            if('html'==PF.renderMode && eOut.dataset.pikchr){
                PF.render(eOut.dataset.pikchr);
            }
        });
        /* For each button with data-cmd=X, map a click handler which
           calls PF.render(X). */
        const cmdClick = function(){PF.render(this.dataset.cmd);};
        EAll('button[data-cmd]').forEach(
            e => e.addEventListener('click', cmdClick, false)
        );

        /**
           TODO: Handle load/import of an external pikchr file.
        */
        if(0) E('#load-pikchr').addEventListener('change',function(){
            const f = this.files[0];
            const r = new FileReader();
            const status = {loaded: 0, total: 0};
            this.setAttribute('disabled','disabled');
            r.addEventListener('loadstart', function(){
                PF.echo("Loading",f.name,"...");
            });
            r.addEventListener('progress', function(ev){
                PF.echo("Loading progress:",ev.loaded,"of",ev.total,"bytes.");
            });
            const that = this;
            r.addEventListener('load', function(){
                that.removeAttribute('disabled');
                stdout("Loaded",f.name+". Opening pikchr...");
                PF.wMsg('open',{
                    filename: f.name,
                    buffer: this.result
                });
            });
            r.addEventListener('error',function(){
                that.removeAttribute('disabled');
                stderr("Loading",f.name,"failed for unknown reasons.");
            });
            r.addEventListener('abort',function(){
                that.removeAttribute('disabled');
                stdout("Cancelled loading of",f.name+".");
            });
            r.readAsArrayBuffer(f);
        });

        EAll('.fieldset.collapsible').forEach(function(fs){
            const legend = E(fs,'span.legend'),
                  content = EAll(fs,':scope > div');
            legend.addEventListener('click', function(){
                fs.classList.toggle('collapsed');
                content.forEach((d)=>d.classList.toggle('hidden'));
            }, false);
        });
        
        /**
           Given a DOM element, this routine measures its "effective
           height", which is the bounding top/bottom range of this element
           and all of its children, recursively. For some DOM structure
           cases, a parent may have a reported height of 0 even though
           children have non-0 sizes.

           Returns 0 if !e or if the element really has no height.
        */
        const effectiveHeight = function f(e){
            if(!e) return 0;
            if(!f.measure){
                f.measure = function callee(e, depth){
                    if(!e) return;
                    const m = e.getBoundingClientRect();
                    if(0===depth){
                        callee.top = m.top;
                        callee.bottom = m.bottom;
                    }else{
                        callee.top = m.top ? Math.min(callee.top, m.top) : callee.top;
                        callee.bottom = Math.max(callee.bottom, m.bottom);
                    }
                    Array.prototype.forEach.call(e.children,(e)=>callee(e,depth+1));
                    if(0===depth){
                        //console.debug("measure() height:",e.className, callee.top, callee.bottom, (callee.bottom - callee.top));
                        f.extra += callee.bottom - callee.top;
                    }
                    return f.extra;
                };
            }
            f.extra = 0;
            f.measure(e,0);
            return f.extra;
        };

        btnRender.click();
        
        /**
           Returns a function, that, as long as it continues to be invoked,
           will not be triggered. The function will be called after it stops
           being called for N milliseconds. If `immediate` is passed, call
           the callback immediately and hinder future invocations until at
           least the given time has passed.

           If passed only 1 argument, or passed a falsy 2nd argument,
           the default wait time set in this function's $defaultDelay
           property is used.

           Source: underscore.js, by way of https://davidwalsh.name/javascript-debounce-function
        */
        const debounce = function f(func, wait, immediate) {
            var timeout;
            if(!wait) wait = f.$defaultDelay;
            return function() {
                const context = this, args = Array.prototype.slice.call(arguments);
                const later = function() {
                    timeout = undefined;
                    if(!immediate) func.apply(context, args);
                };
                const callNow = immediate && !timeout;
                clearTimeout(timeout);
                timeout = setTimeout(later, wait);
                if(callNow) func.apply(context, args);
            };
        };
        debounce.$defaultDelay = 500 /*arbitrary*/;

        const ForceResizeKludge = (function(){
            /* Workaround for Safari mayhem regarding use of vh CSS
               units....  We cannot use vh units to set the main view
               size because Safari chokes on that, so we calculate
               that height here. Larger than ~95% is too big for
               Firefox on Android, causing the input area to move
               off-screen. */
            const appViews = EAll('.app-view');
            const elemsToCount = [
                /* Elements which we need to always count in the
                   visible body size. */
                E('body > header'),
                E('body > footer')
            ];
            const resized = function f(){
                if(f.$disabled) return;
                const wh = window.innerHeight;
                var ht;
                var extra = 0;
                elemsToCount.forEach((e)=>e ? extra += effectiveHeight(e) : false);
                ht = wh - extra;
                appViews.forEach(function(e){
                    e.style.height =
                        e.style.maxHeight = [
                            "calc(", (ht>=100 ? ht : 100), "px",
                            " - 2em"/*fudge value*/,")"
                            /* ^^^^ hypothetically not needed, but both
                               Chrome/FF on Linux will force scrollbars on the
                               body if this value is too small. */
                        ].join('');
                });
            };
            resized.$disabled = true/*gets deleted when setup is finished*/;
            window.addEventListener('resize', debounce(resized, 250), false);
            return resized;
        })();

        delete ForceResizeKludge.$disabled;
        ForceResizeKludge();
    }/*onPFLoaded()*/;
})();
