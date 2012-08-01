# QueryGenerator

TODO: Write a gem description

## Installation

Add this line to your application's Gemfile:

    gem 'query_generator'

This gem has some dependencies on other gems. In detail:

### HAML

A replacement for the default .erb-templates Rails uses.
Don't worry, it is fully compatible to ERB and will parse your old templates.

Just have a look at http://haml.info/

### SASS

Like HAML a way to make writing files easier. In this case, SASS gives you a powerful
language write stylesheet files, including variables, mixins and better nesting.

Just have a look at http://sass-lang.com/

### Barista

Barista is a rails adapter for the popular javascript generator CoffeeScript.
It allows you to write javascript files without having to worry about private/global variables,
brackets (you can still use them if you want) or missing semicolons.

QueryGenerator will automatically register itself as framework, so you don't have to do it manually.


Just have a look at http://coffeescript.org/

Barista has two dependencies itself:

A javascript runtime, e.g.

    gem "therubyracer", :require => nil

If you are using ruby1.8.x, you need to install the JSON gem:

    gem "json"

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install query_generator

## Usage

TODO: Write usage instructions here

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
