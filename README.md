# Corsica

[![Build Status](https://travis-ci.org/whatyouhide/corsica.svg?branch=master&style=flat-square)](https://travis-ci.org/whatyouhide/corsica)

Corsica is a plug and a DSL for handling [CORS][cors-wiki] requests.
[Documentation can be found online][docs].

![Nice Corsica pic][image]
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

Just add the `:corsica` dependency to your project's `mix.exs`:

```elixir
defp dependencies do
  [{:plug, "~> 1.0"},
   {:corsica, "~> 0.4"}]
end
```

and then run `$ mix deps.get`. Corsica is a plug and thus depends on
[Plug][plug] too, but you have to explicitly list Plug as a dependency of your
project (since the dependency is `optional: true` in Corsica).

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
    origins: ["http://localhost", ~r{^https?://(.*\.?)foo\.com$}],
    allow_credentials: true,
    max_age: 600,

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
$ MIX_ENV=docs mix do deps.get, docs
```

Documentation will be generated in the `doc/` directory.

## License

MIT &copy; 2015 Andrea Leopardi, see the [license file](LICENSE.txt).

[image]: http://i.imgur.com/n2DZpEU.jpg
[docs]: https://hexdocs.pm/corsica
[cors-wiki]: http://en.wikipedia.org/wiki/Cross-origin_resource_sharing
[cors-spec]: http://www.w3.org/TR/cors
[plug]: https://github.com/elixir-lang/plug
