/*************************************************!
 *
 *   project:    liteAccordion - a horizontal accordion plugin for jQuery
 *   author:     Nicola Hibbert
 *   url:        http://nicolahibbert.com/liteaccordion-v2/
 *   demo:       http://www.nicolahibbert.com/demo/liteAccordion/
 *
 *   Version:    2.0.2
 *   Copyright:  (c) 2010-2011 Nicola Hibbert
 *   Licence:    MIT
 *
 **************************************************/

;(function($) {

    var LiteAccordion = function(elem, options) {

        var defaults = {
                containerWidth : 960,                   // fixed (px)
                containerHeight : 320,                  // fixed (px)
                headerWidth: 48,                        // fixed (px)

                activateOn : 'click',                   // click or mouseover
                firstSlide : 1,                         // displays slide (n) on page load
                slideSpeed : 800,                       // slide animation speed
                onTriggerSlide : function() {},         // callback on slide activate
                onSlideAnimComplete : function() {},    // callback on slide anim complete

                autoPlay : false,                       // automatically cycle through slides
                pauseOnHover : false,                   // pause on hover
                cycleSpeed : 6000,                      // time between slide cycles
                easing : 'swing',                       // custom easing function

                theme : 'basic',                        // basic, dark, light, or stitch
                rounded : false,                        // square or rounded corners
                enumerateSlides : false,                // put numbers on slides
                linkable : false                        // link slides via hash
            },

        // merge defaults with options in new settings object
            settings = $.extend({}, defaults, options),

        // 'globals'
            slides = elem.children('ol').children('li'),
            header = slides.children(':first-child'),
            slideLen = slides.length,
            slideWidth = 0,
            //cached slidenames (if any)
            slideNames = [],

        // public methods
            methods = {

                // start elem animation
                play : function(index) {
                    var next = core.nextSlide(index && index);

                    if (core.playing) return;

                    // start autoplay
                    core.playing = setInterval(function() {
                        header.eq(next()).trigger('click.liteAccordion');
                    }, settings.cycleSpeed);
                },

                // stop elem animation
                stop : function() {
                    clearInterval(core.playing);
                    core.playing = 0;
                },

                // trigger next slide
                next : function() {
                    methods.stop();

                    header.eq(core.currentSlide === slideLen - 1 ? 0 : core.currentSlide + 1).trigger('click.liteAccordion');
                },

                // trigger previous slide
                prev : function() {
                    methods.stop();
                    header.eq(core.currentSlide - 1).trigger('click.liteAccordion');
                },

                // destroy plugin instance
                destroy : function() {
                    // stop autoplay
                    methods.stop();

                    // remove hashchange event bound to window
                    $(window).unbind('.liteAccordion');

                    // remove generated styles, classes, data, events
                    elem
                        .attr('style', '')
                        .removeClass('accordion basic dark light stitch')
                        .removeData('liteAccordion')
                        .unbind('.liteAccordion')
                        .find('li > :first-child')
                        .unbind('.liteAccordion')
                        .filter('.selected')
                        .removeClass('selected')
                        .end()
                        .find('b')
                        .remove();

                    slides
                        .removeClass('slide')
                        .children()
                        .attr('style', '');
                },

                // poke around the internals (NOT CHAINABLE)
                debug : function() {
                    return {
                        elem : elem,
                        defaults : defaults,
                        settings : settings,
                        methods : methods,
                        core : core,
                        cachedSlideNames: slideNames
                    };
                },

                //Disables the given slide
                disableSlide: function(nameOrIndex) {
                    var slide = core.getSlideByNameOrIndex(nameOrIndex);

                    if (slide != null) {
                        slide.addClass("disabled");
                        core.unbindOpenEvents(slide);
                    }
                },

                //Enables the given slide
                enableSlide: function(nameOrIndex) {
                    var slide = core.getSlideByNameOrIndex(nameOrIndex);

                    if (slide != null) {
                        slide.removeClass("disabled");
                        core.bindOpenEvents(slide);
                    }
                }
            },

        // core utility and animation methods
            core = {

                getContainerWidthInPx: function() {
                    if (typeof settings.containerWidth == "string") {
                        return (jQuery(window).width() * (parseInt(settings.containerWidth.replace("%","")) / 100));
                    } else
                        return settings.containerWidth;
                },

                getContainerHeightInPx: function() {
                    if (typeof settings.containerHeight == "string") {
                        return (jQuery(window).height() * (parseInt(settings.containerHeight.replace("%","")) / 100));
                    } else
                        return settings.containerHeight;
                },

                getSlideByNameOrIndex: function(nameOrIndex) {
                    if (settings.linkable && typeof nameOrIndex == "string") {
                        index = $.inArray(nameOrIndex, slideNames);
                        if (index > -1 && index < slideNames.length)
                            return header.eq(index);
                    } else {
                        if (nameOrIndex > -1 && nameOrIndex < slideNames.length)
                            return header.eq(nameOrIndex);
                    }
                    return null;
                },

                initMissingGlobals: function() {
                    slideWidth = core.getContainerWidthInPx() - slideLen * settings.headerWidth;
                },

                // set style properties
                setStyles : function() {
                    // set container heights, widths, theme & corner style
                    elem
                        .width(core.getContainerWidthInPx())
                        .height(core.getContainerHeightInPx())
                        .addClass('accordion')
                        .addClass(settings.rounded && 'rounded')
                        .addClass(settings.theme);

                    // set tab width, height and selected class
                    slides
                        .addClass('slide')
                        .children(':first-child')
                        .width(core.getContainerHeightInPx())
                        .height(settings.headerWidth)
                        .eq(settings.firstSlide - 1)
                        .addClass('selected');

                    // set initial positions for each slide
                    header.each(function(index) {
                        var $this = $(this),
                            left = index * settings.headerWidth,
                            margin = header.first().next(),
                            offset = parseInt(margin.css('marginLeft'), 10) || parseInt(margin.css('marginRight'), 10) || 0;

                        if (index >= settings.firstSlide) left += slideWidth;

                        $this
                            .css('left', left)
                            .next()
                            .width(slideWidth - offset)
                            .css({ left : left, paddingLeft : settings.headerWidth });

                        // add number to bottom of tab
                        settings.enumerateSlides && $this.append('<b>' + (index + 1) + '</b>');

                    });
                },

                //Resizes the accordion if the window was resized (important for percentual width/height)
                handleWindowResize: function() {
                    core.initMissingGlobals();
                    core.setStyles();
                },

                // bind click and mouseover events
                bindEvents : function() {
                    core.bindOpenEvents(header);

                    // pause on hover (can't use custom events with $.hover())
                    if (settings.pauseOnHover && settings.autoPlay) {
                        elem.bind('mouseover.liteAccordion', function() {
                            core.playing && methods.stop();
                        }).bind('mouseout.liteAccordion', function() {
                                !core.playing && methods.play(core.currentSlide);
                            });
                    }

                    jQuery(window).resize(function() {
                        core.handleWindowResize();
                    });
                },

                bindOpenEvents: function(slideOrSlides) {
                    if (settings.activateOn === 'click') {
                        slideOrSlides.bind('click.liteAccordion', core.triggerSlide);
                    } else if (settings.activateOn === 'mouseover') {
                        slideOrSlides.bind({
                            'mouseover.liteAccordion' : core.triggerSlide,
                            'click.liteAccordion' : core.triggerSlide
                        });
                    }
                },

                unbindOpenEvents: function(slideOrSlides) {
                    if (settings.activateOn === 'click') {
                        slideOrSlides.unbind('click.liteAccordion');
                    } else if (settings.activateOn === 'mouseover') {
                        slideOrSlides.unbind('mouseover.liteAccordion');
                        slideOrSlides.unbind('click.liteAccordion');
                    }
                },

                linkable : function() {
                    var cacheSlideNames = (function() {
                        var slideNames = [];

                        slides.each(function() {
                            if ($(this).attr('name')) slideNames.push(($(this).attr('name')).toLowerCase());
                        });

                        // memoize
                        return cacheSlideNames = slideNames;
                    })();

                    var triggerHash = function(e) {
                        var index;

                        if (e.type === 'load' && !window.location.hash) return;
                        if (e.type === 'hashchange' && core.playing) return;

                        index = $.inArray((window.location.hash.slice(1)).toLowerCase(), cacheSlideNames);
                        if (index > -1 && index < cacheSlideNames.length) header.eq(index).trigger('click.liteAccordion');
                    };

                    $(window).bind({
                        'hashchange.liteAccordion' : triggerHash,
                        'load.liteAccordion' : triggerHash
                    });
                },

                // counter for autoPlay (zero index firstSlide on init)
                currentSlide : settings.firstSlide - 1,

                // next slide index
                nextSlide : function(index) {
                    var next = index + 1 || core.currentSlide + 1;

                    // closure
                    return function() {
                        return next++ % slideLen;
                    };
                },

                // holds interval counter
                playing : 0,

                // animates left and right groups of slides
                // side: denotes left side
                animSlideGroup : function(index, next, side) {
                    var filterExpr = side ? ':lt(' + (index + 1) + ')' : ':gt(' + index + ')';

                    slides
                        .filter(filterExpr)
                        .each(function() {
                            var $this = $(this),
                                slideIndex = slides.index($this);

                            $this
                                .children()
                                .stop(true)
                                .animate({
                                    left : (side ? 0 : slideWidth) + slideIndex * settings.headerWidth
                                },
                                settings.slideSpeed,
                                settings.easing,
                                function() {
                                    // flag ensures that fn is only called one time per triggerSlide
                                    if (!core.slideAnimCompleteFlag) {
                                        settings.onSlideAnimComplete.call(next);
                                        core.slideAnimCompleteFlag = true;
                                    }
                                });
                        });
                },

                slideAnimCompleteFlag : false,

                // trigger slide animation
                triggerSlide : function(e) {
                    var $this = $(this),
                        index = header.index($this),
                        next = $this.next();

                    // update core.currentSlide
                    core.currentSlide = index;

                    // reset onSlideAnimComplete callback flag
                    core.slideAnimCompleteFlag = false;

                    // remove, then add selected class
                    header.removeClass('selected').filter($this).addClass('selected');

                    // reset current slide index in core.nextSlide closure
                    if (e.originalEvent && settings.autoPlay) {
                        methods.stop();
                        methods.play(index);
                    }

                    // set location.hash
                    if (settings.linkable && !core.playing) window.location.hash = $this.parent().attr('name');

                    // trigger callback in context of sibling div
                    settings.onTriggerSlide.call(next);

                    // animate left & right groups
                    core.animSlideGroup(index, next, true);
                    core.animSlideGroup(index, next);
                },

                ieClass : function() {
                    var version = +($.browser.version).charAt(0);

                    if (version < 7) methods.destroy();
                    if (version === 7 || version === 8) {
                        slides.each(function(index) {
                            $(this).addClass('slide-' + index);
                        });
                    }

                    elem.addClass('ie ie' + version);
                },

                init : function() {
                    //Set globals which needed the core namespace
                    core.initMissingGlobals();

                    // test for ie
                    if ($.browser.msie) core.ieClass();

                    // init styles and events
                    core.setStyles();
                    core.bindEvents();

                    // check slide speed is not faster than cycle speed
                    if (settings.cycleSpeed < settings.slideSpeed) settings.cycleSpeed = settings.slideSpeed;

                    // init hash links
                    if (settings.linkable && 'onhashchange' in window) core.linkable();

                    //Set slide name cache anyway
                    slides.each(function(index) {
                        if ($(this).attr('name'))
                            slideNames.push(($(this).attr('name')).toLowerCase());
                        else
                            slideNames.push("no-name-" + index);
                    });

                    // init autoplay
                    settings.autoPlay && methods.play();
                }
            };

        // init plugin
        core.init();

        // expose methods
        return methods;
    };

    $.fn.liteAccordion = function(methodOrOptions) {
        var elem = this,
            instance = elem.data('liteAccordion');

        if ( typeof methodOrOptions === 'object' || ! methodOrOptions ) {
            //Initialize a new accordion or return the existing one
            return elem.each(function() {
                var liteAccordion;

                // if plugin already instantiated, return
                if (instance) return;

                // otherwise create a new instance
                liteAccordion = new LiteAccordion(elem, methodOrOptions);
                elem.data('liteAccordion', liteAccordion);
            });
        } else if ( instance && instance[methodOrOptions] ) {
            //If the instance already exists and an existing method name was given,
            //execute it with the given parameters (optional)
            var result = instance[ methodOrOptions ].apply( this, Array.prototype.slice.call( arguments, 1 ));

            // debug method isn't chainable b/c we need the debug object to be returned
            return (methodOrOptions == "debug") ? result : elem;
        } else {
            $.error( 'Method ' +  methodOrOptions + ' does not exist on liteAccordion' );
        }
    };

})(jQuery);