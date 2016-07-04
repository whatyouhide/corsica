# Changelog

## v0.5.0

* Drop support for anonymous functions in the list of `:origins` (it was a
  mistake to support that in the first place!)
* Add support for `{module, function}` tuples in the list of `:origins`
  (`module.function` will be called with the origin as its argument and will
  decide if such origin is allowed)
* Change the `:log` option from being a log level or `false` to being a keyword
  list with log levels or `false` for each log "type" (e.g., `:rejected` or
  `:invalid`)

## v0.4.2

* Fix a bug where options given to a `Corsica.Router` weren't properly escaped
  and caused a "invalid quoted expression" error

## v0.4.1

* Fix a typo in a logged message

## v0.4.0

* Logging is now more detailed (e.g., it logs what header is missing from
  `:allow_headers`)
* Accept options when a module calls `use Corsica.Router` and make these options
  overridable in each `Corsica.Router.resource/1-2` macro

## v0.3.0

* Add logging support
