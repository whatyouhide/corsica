# Changelog

## v2.1.3

  * Remove Dialyzer PLTs from the Hex package. This has no functional impact whatsoever on the library. The PLTs were accidentally published together with the Hex package, which just results in an unnecessarily large Hex package.

## v2.1.2

  * Fix a bug with typespecs and Dialyzer.

## v2.1.1

### Bug fixes

  * Fix a small issue with preflight requests and the `:passthrough_non_cors_requests` option.
  * Add the `Corsica.options/0` type.

## v2.1.0

### Improvements

  * Add the `:passthrough_non_cors_requests` option.
  * Add the `Corsica.sanitized_options/0` and `Corsica.options/0` types.

## v2.0.0

### Breaking changes

  * The `:origins` option is now **required**. Not having this option used to warn before this version.
  * The `:log` option was removed in favor of `Corsica.Telemetry`.

### Improvements

  * Start emitting Telemetry events (see `Corsica.Telemetry`).
  * Bump Elixir requirement to 1.11+.
  * Response headers that contain lists (such as `access-control-expose-headers`) are now joined *without spaces*, so what could be `GET, POST, DELETE` before is now `GET,POST,DELETE`. Every byte's important.

**Upgrading** from 1.x to 2.0.0 is a matter of these things:

  * If you're not specifying the `:origins` options when using Corsica, add `origins: "*"` to all the places you're using Corsica (as a plug, through `Corsica.Router`, or through the functions in the `Corsica` module).

  * If you were using the `:log` option, remove it and call this in your application's `start/2` callback:

    ```elixir
    log_levels = # what you were using before as the :log option
    Corsica.Telemetry.attach_default_handler(log_levels: log_levels)

    Supervisor.start_link(...)
    ```

## v1.3.0

### Improvements

  * Add support for the `:allow_private_network` option to control the [`Access-Control-Allow-Private-Network` header](https://wicg.github.io/private-network-access/#http-headerdef-access-control-allow-private-network).
  * Fix runtime warnings for the `:warn` logger level.

## v1.2.0

This version **drops support for Elixir 1.7 and lower**.

### Improvements

  * Add support for `{module, function, args}` as a value for the `:origins` option.

## v1.1.3

### Bug fixes

  * Send the `vary: origin` header when the origin is not `*`. We were doing this in some cases before but we missed a handful of other cases. See https://github.com/whatyouhide/corsica/pull/45.

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
