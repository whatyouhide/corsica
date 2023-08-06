# Corsica

[![hex.pm badge](https://img.shields.io/badge/Package%20on%20hex.pm-informational)](https://hex.pm/packages/corsica)
[![Documentation badge](https://img.shields.io/badge/Documentation-ff69b4)][docs]
[![CI](https://github.com/whatyouhide/corsica/workflows/CI/badge.svg)](https://github.com/whatyouhide/corsica/actions/workflows/main.yml)
[![Coverage Status](https://coveralls.io/repos/github/whatyouhide/corsica/badge.svg?branch=main)](https://coveralls.io/github/whatyouhide/corsica?branch=main)

Corsica is a plug and a DSL for handling [CORS][cors-wiki] requests.
[Documentation can be found online][docs].

![Landscape image of a sunset in Corsica, with the sea in the foreground and mountains in the background](https://user-images.githubusercontent.com/3890250/237011378-833e6fff-fc6b-41b4-94ca-ae75c0109aff.jpg)
> Photo by <a href="https://unsplash.com/@the_bracketeer?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText">Hendrik Cornelissen</a> on <a href="https://unsplash.com/photos/b_oRl_WOMVM?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText">Unsplash</a>

*(I had to include a nice pic because, let's be honest, CORS requests aren't the
most fun thing in the world, are they?)*

## Features

* Is compliant with the [W3C CORS specification][cors-spec]
* Provides both low-level CORS utilities as well as high-level facilities (like
    a built-in plug and a CORS-focused router)
* Handles preflight requests like a breeze
* Never sends any CORS headers if the CORS request is not valid (smaller
    requests, yay!)

## Installation

Add the `:corsica` dependency to your project's `mix.exs`:

```elixir
defp deps do
  [
    {:plug, "~> 1.0"},
    {:corsica, "~> 2.0"}
  ]
end
```

and then run `$ mix deps.get`.

## Overview

You can use Corsica both as a plug as well as a router generator. To use it as a
plug, just plug it into your plug pipeline:

```elixir
defmodule MyApp.Endpoint do
  plug Logger
  plug Corsica, origins: "http://foo.com"
  plug MyApp.Router
end
```

To gain finer control over which resources are CORS-enabled and with what
options, you can use the `Corsica.Router` module:

```elixir
defmodule MyApp.CORS do
  use Corsica.Router,
    origins: ["http://localhost", ~r{^https?://(.*\.)?foo\.com$}],
    allow_credentials: true,
    max_age: 600

  resource "/public/*", origins: "*"
  resource "/*"
end

defmodule MyApp.Endpoint do
  plug Logger
  plug MyApp.CORS
  plug MyApp.Router
end
```

This is only a brief overview of what Corsica can do. To find out more, head to
the [online documentation][docs].

### Common issues

Note that Corsica is compliant with the W3C CORS specification, which means CORS
response headers are not sent for invalid CORS requests. The documentation goes
into more detail about this, but it's worth noting so that the first impression
is not that Corsica is doing nothing. One common pitfall is not including CORS
request headers in your requests: this makes the request an invalid CORS
request, so Corsica won't add any CORS response headers. Be sure to add at least
the `Origin` header:

```sh
curl localhost:4000 -v -H "Origin: http://foo.com"
```

There is a [dedicated page in the documentation](https://hexdocs.pm/corsica/common-issues.html) that covers some of the common issues with CORS (and Corsica in part).

## Contributing

If you find a bug, something unclear (including in the documentation!) or a
behaviour that is not compliant with the latest revision of the
[official CORS specification][cors-spec], please open an issue on GitHub.

If you want to contribute to code or documentation, fork the repository and then
open a Pull Request
([how-to](https://help.github.com/articles/using-pull-requests/)). Before
opening a Pull Request, make sure all the tests passes by running `$ mix test`
in your shell. If you're contributing to documentation, you can preview the
generated documentation locally by running:

```bash
mix docs
```

Documentation will be generated in the `doc/` directory.

## License

MIT &copy; 2015 Andrea Leopardi, see the [license file](LICENSE.txt).

[docs]: https://hexdocs.pm/corsica
[cors-wiki]: http://en.wikipedia.org/wiki/Cross-origin_resource_sharing
[cors-spec]: http://www.w3.org/TR/cors
[plug]: https://github.com/elixir-lang/plug
