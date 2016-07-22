# opal-minitest

Minitest, now for Opal! (not complete)

## Usage

First, install this gem in an Opal project.

```ruby
# Gemfile
gem 'opal-minitest'
```

`$ bundle install`

Then, add this gem's Rake task to a Rakefile.

```ruby
# Rakefile
require 'opal/minitest/rake_task'
Opal::Minitest::RakeTask.new
```

Finally, run Rake.

`$ bundle exec rake`

This will run tests and code in all project files matching `test/{test_helper,**/*_test}.{rb,opal}`. Try the example!

You can pass CLI options to Minitest via the TESTOPTS environment variable:

`$ bundle exec rake TESTOPTS="--verbose -n /assert/"`

## Status

Opal Minitest supports everything in minitest/unit except parallel test running, plugins, and `#capture_subprocess_io`.

Opal Minitest does not yet support minitest/spec, minitest/benchmark, minitest/mock, or minitest/pride.

All code differences from normal Minitest are documented with the label `PORT`.
