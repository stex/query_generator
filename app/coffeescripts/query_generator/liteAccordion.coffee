# Project: liteAccordion - a horizontal accordion plugin for jQuery
# Description:
# Author: Nicola Hibbert, Extended and converted to coffee-script by Stefan Exner
# License:
# URL: http://nicolahibbert.com/liteaccordion-v2/

(($, window) ->
  # Create the defaults once
  pluginName = 'liteAccordion'
  document = window.document
  defaults =
    containerWidth : 960,                   # fixed (px) or percentual ("90%")
    containerHeight : 320,                  # fixed (px) or percentual ("90%")
    headerWidth: 48,                        # fixed (px)
    contentPadding: 0,                      # fixed (px) padding from slide header

    activateOn : 'click',                   # click or mouseover
    firstSlide : 1,                         # displays slide (n) on page load
    slideSpeed : 800,                       # slide animation speed
    onTriggerSlide : ->,                    # callback on slide activate
    onSlideAnimComplete : ->,               # callback on slide anim complete

    autoPlay : false,                       # automatically cycle through slides
    pauseOnHover : false,                   # pause on hover
    cycleSpeed : 6000,                      # time between slide cycles
    easing : 'swing',                       # custom easing function

    theme : 'basic',                        # basic, dark, light, or stitch
    rounded : false,                        # square or rounded corners
    enumerateSlides : false,                # put numbers on slides
    linkable : false                        # link slides via hash

  # The actual plugin constructor
  class LiteAccordion

    constructor: (element, options) ->
      @element = $(element)

      @_defaults = defaults
      @_name = pluginName

      @options = $.extend {}, defaults, options
      @slides =  $(element).children('ol').children('li')
      @header =  @slides.children(':first-child')
      @slideLen =  @slides.length
      @slideNames = []

      #Flags used for animations
      @playing =  0
      @slideAnimCompleteFlag = false

      @currentSlide = @options.firstSlide - 1

      core.instance = @

      core.init()

    ###
    -----------------------------
    - Helper and core functions -
    -----------------------------
    ###

    core =
      instance: null

      #Returns the container width in px. If the given option is a percentage value,
      #it will calculate the correct amount of pixel based on the window width
      getContainerWidthInPx: ->
        if (typeof @instance.options.containerWidth == "string")
          return $(window).width() * (parseInt(@instance.options.containerWidth.replace("%","")) / 100)
        @instance.options.containerWidth

      #Returns the container height in px. If the given option is a percentage value,
      #it will calculate the correct amount of pixel based on the window height
      getContainerHeightInPx: ->
        if (typeof @instance.options.containerHeight == "string")
          return $(window).height() * (parseInt(@instance.options.containerHeight.replace("%","")) / 100)
        @instance.options.containerHeight

      # Returns the slide DOM object for the given name or index
      # As the plugin author decided to start the indexes for public
      # methods and settings with 1, this is done here as well.
      #--------------------------------------------------------------
      getSlideByNameOrIndex: (nameOrIndex) ->
        index = if (typeof nameOrIndex == "string") then $.inArray(nameOrIndex, @instance.slideNames) else nameOrIndex - 1
        if (index > -1 && index < @instance.slideNames.length) then @instance.header.eq(index) else null

      # Calculates the current slide width
      #--------------------------------------------------------------
      getSlideWidth: ->
        @getContainerWidthInPx() - @instance.slideLen * @instance.options.headerWidth;

      getName: ->
        "core namespace"

      # Sets the styles for the container and the slides
      #--------------------------------------------------------------
      setStyles: ->
        #set container heights, widths, theme & corner style

        @instance.element
          .width(@getContainerWidthInPx())
          .height(@getContainerHeightInPx())
          .addClass('accordion')
          .addClass(@instance.options.rounded && 'rounded')
          .addClass(@instance.options.theme)

        #set tab width, height and selected class for slides
        @instance.slides
          .addClass('slide')
          .children(':first-child')
          .width(@getContainerHeightInPx())
          .height(@instance.options.headerWidth)
          .eq(@instance.options.firstSlide - 1)
          .addClass('selected')

        @instance.header.each (index, currentHeader) ->
          left = index * core.instance.options.headerWidth
          margin = core.instance.header.first().next()
          offset = parseInt(margin.css('marginLeft'), 10) || parseInt(margin.css('marginRight'), 10) || 0

          left += core.getSlideWidth() if (index >= core.instance.options.firstSlide)

          $(currentHeader)
            .css('left', left)
            .next()
            .width(core.instance.slideWidth - offset)
            .css({ left : left, paddingLeft : core.instance.options.headerWidth + core.instance.options.contentPadding })

          #add number to bottom of tab
          core.instance.options.enumerateSlides && $(currentHeader).append('<b>' + (index + 1) + '</b>')

      # Function which is executed when the window is resized
      # This is especially important if the width/height was set to a
      # procentual value
      #--------------------------------------------------------------
      handleWindowResize: ->
        core.setStyles()

      # Caches the slide names or set default ones
      #--------------------------------------------------------------
      cacheSlideNames: ->
        @instance.slides.each (index, slide) ->
          if ($(slide).attr('name'))
            core.instance.slideNames.push(($(slide).attr('name')).toLowerCase())
          else
            core.instande.slideNames.push("no-name-" + index)

      # Binds the click/mouseover events to the accordion headers
      #--------------------------------------------------------------
      bindOpenEvents: (slideOrSlides) ->
        slideOrSlides.bind('click.liteAccordion', core.triggerSlide)
        slideOrSlides.bind('mouseover.liteAccordion', core.triggerSlide) if @instance.options.activateOn == "mouseOver"

      # Removes the onclick/mouseover events from the accordion headers
      #--------------------------------------------------------------
      unbindOpenEvents: (slideOrSlides) ->
        slideOrSlides.unbind('click.liteAccordion')
        slideOrSlides.unbind('mouseover.liteAccordion') if @instance.options.activateOn == "mouseOver"

      # Binds click and mouseover events for all slides
      #--------------------------------------------------------------
      bindEvents: ->
        core.bindOpenEvents(@instance.header)

        # pause on hover (can't use custom events with $.hover())
        if (@instance.options.pauseOnHover && @instance.options.autoPlay)
          @instance.element.bind 'mouseover.liteAccordion', ->
            @instance.playing && methods.stop()
          @instance.element.bind 'mouseout.liteAccordion', ->
            !@instance.playing && methods.play(@instance.currentSlide)

        #Bind window resize handler
        $(window).bind "resize.liteAccordion", core.handleWindowResize

      # Sets the handlers to trigger a slide by calling its name
      #--------------------------------------------------------------
      linkable: ->
        triggerHash = (e) ->
          if (e.type == 'load' && !window.location.hash) then return
          if (e.type == 'hashchange' && @instance.playing) then return

          @getSlideByNameOrIndex((window.location.hash.slice(1)).toLowerCase())

        $(window).bind
          'hashchange.liteAccordion' : triggerHash
          'load.liteAccordion' : triggerHash
        null

      # Calculates the next slide index (used for autoplay)
      #--------------------------------------------------------------
      nextSlide: (index) ->
        next = index + 1 || @instance.currentSlide + 1

        #Closure
        () ->
          next++ % @instance.slideLen

      # animates left and right groups of slides
      # side: denotes left side
      #--------------------------------------------------------------
      animSlideGroup: (index, next, side) ->
        filterExpr = if side then ':lt(' + (index + 1) + ')' else ':gt(' + index + ')'

        @instance.slides
          .filter(filterExpr)
          .each (index, slide) ->
            $(slide)
              .children()
              .stop(true)
              .animate(
                {left : (if side then 0 else core.instance.slideWidth) + index * core.instance.options.headerWidth},
                core.instance.options.slideSpeed,
                core.instance.options.easing,
                () ->
                  if (!core.instance.slideAnimCompleteFlag)
                    core.instance.options.onSlideAnimComplete.call(next)
                    core.instance.slideAnimCompleteFlag = true)

      # Triggers the slide animation
      #--------------------------------------------------------------
      triggerSlide: (e) ->
        $this = $(this)
        index = core.instance.header.index($this)
        next = $this.next()

        #Set the new current Slide
        core.instance.currentSlide = index

        #Reset the callback flag
        core.instance.slideAnimCompleteFlag = false

        #Set the new "selected" class
        core.instance.header.removeClass('selected').filter($this).addClass('selected')

        #Reset current slide index in nextSlide() closure
        if (e.originalEvent && core.instance.options.autoPlay)
          methods.stop()
          methods.play(index)

        #Set location hash if linking is enabled
        window.location.hash = $this.parent().attr('name') if (core.instance.options.linkable && !core.instance.playing)

        #trigger callback in context of sibling div
        core.instance.options.onTriggerSlide.call(next)

        #Animate left and right groups
        core.animSlideGroup(index, next, true)
        core.animSlideGroup(index, next)

      # Sets some special options for our favourite browser
      #--------------------------------------------------------------
      ieClass: ->
        version = +($.browser.version).charAt(0);

        if (version < 7) then methods.destroy()

        if (version == 7 || version == 8)
          slides.each (index) ->
            $(this).addClass('slide-' + index)

        @instance.element.addClass('ie ie' + version)

      init: ->
        #test for ie
        if ($.browser.msie) then @ieClass()

        @setStyles()
        @bindEvents()

        @.cacheSlideNames()

        #check slide speed is not faster than cycle speed
        @instance.options.cycleSpeed = @instance.options.slideSpeed if (@instance.options.cycleSpeed < @instance.options.slideSpeed)

        #init hash links
        @linkable() if (@instance.options.linkable && 'onhashchange' in window)

        #init autoplay
        @instance.options.autoPlay && methods.play()

    ###
    -----------------------------
    -      Exported Methods     -
    -----------------------------
    ###

    methods =
      # start elem animation
      play: (index) ->
        next = core.nextSlide(index && index)
        return if (core.instance.playing)

        #start autoplay
        core.instance.playing = setInterval(
          () -> core.instance.header.eq(next()).trigger('click.liteAccordion')
          core.instance.options.cycleSpeed)

      #Stop the element animation
      stop: () ->
        clearInterval(core.instance.playing)
        core.instance.playing = 0

      #Triggers the next slide
      next: () ->
        @stop()
        core.instance.header.eq(core.instance.currentSlide == core.instance.slideLen - 1 ? 0 : core.instance.currentSlide + 1).trigger('click.liteAccordion')

      #Triggers the previous slide
      prev: () ->
        @stop()
        core.instance.header.eq(core.instance.currentSlide - 1).trigger('click.liteAccordion')

      #Destroys the plugin instance
      destroy: () ->
        #stop autoplay
        methods.stop()

        #remove hashchange event bound to window
        $(window).unbind('.liteAccordion')

        #remove generated styles, classes, data, events
        core.instance.element
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
          .remove()

        core.instance.slides
          .removeClass('slide')
          .children()
          .attr('style', '');

      #Disables the given slide (name or index)
      disableSlide: (nameOrIndex) ->
        slide = core.getSlideByNameOrIndex(nameOrIndex)
        if (slide?)
          slide.addClass("disabled")
          core.unbindOpenEvents(slide)

      #Enables the given slide (name or index)
      enableSlide: (nameOrIndex) ->
        slide = core.getSlideByNameOrIndex(nameOrIndex)
        if (slide?)
          slide.removeClass("disabled")
          core.bindOpenEvents(slide)

  $.fn[pluginName] = (options) ->
    instance = $.data(this, "plugin_#{pluginName}")
    if (typeof options == "object" || !options)
      @each ->
        if !$.data(this, "plugin_#{pluginName}")
          $.data(@, "plugin_#{pluginName}", new LiteAccordion(@, options))
    else if (instance && instance.methods[options])
      instance.methods[options].apply(@, Array.prototype.slice.call( arguments, 1 ))
    else
      $.error( 'Method ' +  options + ' does not exist on liteAccordion' );

)(jQuery, window)