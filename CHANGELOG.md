# Changelog

## v1.1.2

### Improvements

  * Drop the cowboy dependency completely (see #40).

## v1.1.0

### Improvements

  * Warn if the `:origins` option is not explicitly provided. This warning will become an error in future Corsica versions.

## v1.1.0

### Bug fixes

  * Correctly allow "simple methods" and "simple headers" in preflight requests. See the documentation for the `:allow_methods` and `:allow_headers` options.

### Improvements

  * Allow `:all` as value for the `:allow_methods` and `:allow_headers` options.

## v1.0.0

### Breaking changes

  * Drop support for older Elixir versions and require Elixir `~> 1.3`.

### Improvements

  * Improve logs.

## v0.5.0

### Breaking changes

  * Drop support for anonymous functions in the list of `:origins` (it was a mistake to support that in the first place!).
  * Change the `:log` option from being a log level or `false` to being a keyword list with log levels or `false` for each log "type" (for example, `:rejected` or `:invalid`).

### Improvements

  * Add support for `{module, function}` tuples in the list of `:origins` (`module.function` will be called with the origin as its argument and will decide if such origin is allowed).

## v0.4.2

### Bug fixes

  * Fix a bug where options given to a `Corsica.Router` weren't properly escaped and caused a "invalid quoted expression" error.

## v0.4.1

### Bug fixes

  * Fix a typo in a logged message.

## v0.4.0

### Improvements

  * Logging is now more detailed (for example, it logs what header is missing from `:allow_headers`).
  * Accept options when a module calls `use Corsica.Router` and make these options overridable in each `Corsica.Router.resource/1-2` macro.

## v0.3.0

### Improvements

* Add support for logging.
