(function() {
  var __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  (function($, window) {
    var LiteAccordion, defaults, document, pluginName;
    pluginName = 'liteAccordion';
    document = window.document;
    defaults = {
      containerWidth: 960,
      containerHeight: 320,
      headerWidth: 48,
      contentPadding: 0,
      activateOn: 'click',
      firstSlide: 1,
      slideSpeed: 800,
      onTriggerSlide: function() {},
      onSlideAnimComplete: function() {},
      autoPlay: false,
      pauseOnHover: false,
      cycleSpeed: 6000,
      easing: 'swing',
      theme: 'basic',
      rounded: false,
      enumerateSlides: false,
      linkable: false
    };
    LiteAccordion = (function() {
      var core, methods;

      function LiteAccordion(element, options) {
        this.element = $(element);
        this._defaults = defaults;
        this._name = pluginName;
        this.options = $.extend({}, defaults, options);
        this.slides = $(element).children('ol').children('li');
        this.header = this.slides.children(':first-child');
        this.slideLen = this.slides.length;
        this.slideNames = [];
        this.playing = 0;
        this.slideAnimCompleteFlag = false;
        this.currentSlide = this.options.firstSlide - 1;
        core.instance = this;
        core.init();
      }

      /*
          -----------------------------
          - Helper and core functions -
          -----------------------------
      */


      core = {
        instance: null,
        getContainerWidthInPx: function() {
          if (typeof this.instance.options.containerWidth === "string") {
            return $(window).width() * (parseInt(this.instance.options.containerWidth.replace("%", "")) / 100);
          }
          return this.instance.options.containerWidth;
        },
        getContainerHeightInPx: function() {
          if (typeof this.instance.options.containerHeight === "string") {
            return $(window).height() * (parseInt(this.instance.options.containerHeight.replace("%", "")) / 100);
          }
          return this.instance.options.containerHeight;
        },
        getSlideByNameOrIndex: function(nameOrIndex) {
          var index;
          index = typeof nameOrIndex === "string" ? $.inArray(nameOrIndex, this.instance.slideNames) : nameOrIndex - 1;
          if (index > -1 && index < this.instance.slideNames.length) {
            return this.instance.header.eq(index);
          } else {
            return null;
          }
        },
        getSlideWidth: function() {
          return this.getContainerWidthInPx() - this.instance.slideLen * this.instance.options.headerWidth;
        },
        getName: function() {
          return "core namespace";
        },
        setStyles: function() {
          this.instance.element.width(this.getContainerWidthInPx()).height(this.getContainerHeightInPx()).addClass('accordion').addClass(this.instance.options.rounded && 'rounded').addClass(this.instance.options.theme);
          this.instance.slides.addClass('slide').children(':first-child').width(this.getContainerHeightInPx()).height(this.instance.options.headerWidth).eq(this.instance.options.firstSlide - 1).addClass('selected');
          return this.instance.header.each(function(index, currentHeader) {
            var left, margin, offset;
            left = index * core.instance.options.headerWidth;
            margin = core.instance.header.first().next();
            offset = parseInt(margin.css('marginLeft'), 10) || parseInt(margin.css('marginRight'), 10) || 0;
            if (index >= core.instance.options.firstSlide) {
              left += core.getSlideWidth();
            }
            $(currentHeader).css('left', left).next().width(core.instance.slideWidth - offset).css({
              left: left,
              paddingLeft: core.instance.options.headerWidth + core.instance.options.contentPadding
            });
            return core.instance.options.enumerateSlides && $(currentHeader).append('<b>' + (index + 1) + '</b>');
          });
        },
        handleWindowResize: function() {
          return core.setStyles();
        },
        cacheSlideNames: function() {
          return this.instance.slides.each(function(index, slide) {
            if ($(slide).attr('name')) {
              return core.instance.slideNames.push(($(slide).attr('name')).toLowerCase());
            } else {
              return core.instande.slideNames.push("no-name-" + index);
            }
          });
        },
        bindOpenEvents: function(slideOrSlides) {
          slideOrSlides.bind('click.liteAccordion', core.triggerSlide);
          if (this.instance.options.activateOn === "mouseOver") {
            return slideOrSlides.bind('mouseover.liteAccordion', core.triggerSlide);
          }
        },
        unbindOpenEvents: function(slideOrSlides) {
          slideOrSlides.unbind('click.liteAccordion');
          if (this.instance.options.activateOn === "mouseOver") {
            return slideOrSlides.unbind('mouseover.liteAccordion');
          }
        },
        bindEvents: function() {
          core.bindOpenEvents(this.instance.header);
          if (this.instance.options.pauseOnHover && this.instance.options.autoPlay) {
            this.instance.element.bind('mouseover.liteAccordion', function() {
              return this.instance.playing && methods.stop();
            });
            this.instance.element.bind('mouseout.liteAccordion', function() {
              return !this.instance.playing && methods.play(this.instance.currentSlide);
            });
          }
          return $(window).bind("resize.liteAccordion", core.handleWindowResize);
        },
        linkable: function() {
          var triggerHash;
          triggerHash = function(e) {
            if (e.type === 'load' && !window.location.hash) {
              return;
            }
            if (e.type === 'hashchange' && this.instance.playing) {
              return;
            }
            return this.getSlideByNameOrIndex((window.location.hash.slice(1)).toLowerCase());
          };
          $(window).bind({
            'hashchange.liteAccordion': triggerHash,
            'load.liteAccordion': triggerHash
          });
          return null;
        },
        nextSlide: function(index) {
          var next;
          next = index + 1 || this.instance.currentSlide + 1;
          return function() {
            return next++ % this.instance.slideLen;
          };
        },
        animSlideGroup: function(index, next, side) {
          var filterExpr;
          filterExpr = side ? ':lt(' + (index + 1) + ')' : ':gt(' + index + ')';
          return this.instance.slides.filter(filterExpr).each(function(index, slide) {
            return $(slide).children().stop(true).animate({
              left: (side ? 0 : core.instance.slideWidth) + index * core.instance.options.headerWidth
            }, core.instance.options.slideSpeed, core.instance.options.easing, function() {
              if (!core.instance.slideAnimCompleteFlag) {
                core.instance.options.onSlideAnimComplete.call(next);
                return core.instance.slideAnimCompleteFlag = true;
              }
            });
          });
        },
        triggerSlide: function(e) {
          var $this, index, next;
          $this = $(this);
          index = core.instance.header.index($this);
          next = $this.next();
          core.instance.currentSlide = index;
          core.instance.slideAnimCompleteFlag = false;
          core.instance.header.removeClass('selected').filter($this).addClass('selected');
          if (e.originalEvent && core.instance.options.autoPlay) {
            methods.stop();
            methods.play(index);
          }
          if (core.instance.options.linkable && !core.instance.playing) {
            window.location.hash = $this.parent().attr('name');
          }
          core.instance.options.onTriggerSlide.call(next);
          core.animSlideGroup(index, next, true);
          return core.animSlideGroup(index, next);
        },
        ieClass: function() {
          var version;
          version = +$.browser.version.charAt(0);
          if (version < 7) {
            methods.destroy();
          }
          if (version === 7 || version === 8) {
            slides.each(function(index) {
              return $(this).addClass('slide-' + index);
            });
          }
          return this.instance.element.addClass('ie ie' + version);
        },
        init: function() {
          if ($.browser.msie) {
            this.ieClass();
          }
          this.setStyles();
          this.bindEvents();
          this.cacheSlideNames();
          if (this.instance.options.cycleSpeed < this.instance.options.slideSpeed) {
            this.instance.options.cycleSpeed = this.instance.options.slideSpeed;
          }
          if (this.instance.options.linkable && __indexOf.call(window, 'onhashchange') >= 0) {
            this.linkable();
          }
          return this.instance.options.autoPlay && methods.play();
        }
      };

      /*
          -----------------------------
          -      Exported Methods     -
          -----------------------------
      */


      methods = {
        play: function(index) {
          var next;
          next = core.nextSlide(index && index);
          if (core.instance.playing) {
            return;
          }
          return core.instance.playing = setInterval(function() {
            return core.instance.header.eq(next()).trigger('click.liteAccordion');
          }, core.instance.options.cycleSpeed);
        },
        stop: function() {
          clearInterval(core.instance.playing);
          return core.instance.playing = 0;
        },
        next: function() {
          var _ref;
          this.stop();
          return core.instance.header.eq((_ref = core.instance.currentSlide === core.instance.slideLen - 1) != null ? _ref : {
            0: core.instance.currentSlide + 1
          }).trigger('click.liteAccordion');
        },
        prev: function() {
          this.stop();
          return core.instance.header.eq(core.instance.currentSlide - 1).trigger('click.liteAccordion');
        },
        destroy: function() {
          methods.stop();
          $(window).unbind('.liteAccordion');
          core.instance.element.attr('style', '').removeClass('accordion basic dark light stitch').removeData('liteAccordion').unbind('.liteAccordion').find('li > :first-child').unbind('.liteAccordion').filter('.selected').removeClass('selected').end().find('b').remove();
          return core.instance.slides.removeClass('slide').children().attr('style', '');
        },
        disableSlide: function(nameOrIndex) {
          var slide;
          slide = core.getSlideByNameOrIndex(nameOrIndex);
          if ((slide != null)) {
            slide.addClass("disabled");
            return core.unbindOpenEvents(slide);
          }
        },
        enableSlide: function(nameOrIndex) {
          var slide;
          slide = core.getSlideByNameOrIndex(nameOrIndex);
          if ((slide != null)) {
            slide.removeClass("disabled");
            return core.bindOpenEvents(slide);
          }
        }
      };

      return LiteAccordion;

    })();
    return $.fn[pluginName] = function(options) {
      var instance;
      instance = $.data(this, "plugin_" + pluginName);
      if (typeof options === "object" || !options) {
        return this.each(function() {
          if (!$.data(this, "plugin_" + pluginName)) {
            return $.data(this, "plugin_" + pluginName, new LiteAccordion(this, options));
          }
        });
      } else if (instance && instance.methods[options]) {
        return instance.methods[options].apply(this, Array.prototype.slice.call(arguments, 1));
      } else {
        return $.error('Method ' + options + ' does not exist on liteAccordion');
      }
    };
  })(jQuery, window);

}).call(this);
