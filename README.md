# Corsica

[![Build Status](https://travis-ci.org/whatyouhide/corsica.svg?branch=master&style=flat-square)](https://travis-ci.org/whatyouhide/corsica)
[![Hex.pm](https://img.shields.io/hexpm/v/corsica.svg)](https://hex.pm/packages/corsica)

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
   {:corsica, "~> 1.0"}]
end
```

Ensure `:corsica` is started before your application (only if using
`:applications` and not using application inference):

```elixir
def application do
  [applications: [:corsica]]
end
```

and then run `$ mix deps.get`.

## Overview

You can use Corsica both as a plug as well as a router generator. To use it as a
plug, just plug it into your plug pipeline:

```elixir
defmodule MyApp.Endpoint do
  plug Logger
  plug Corsica, origins: "http://foo.com" # default is "*" which allows any origin
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

## Common Issues

### Browser gives 'Origin ... is therefore not allowed access' error

When attempting to do a CORS request to your Elixir server, your browser might log the following error in the console:

> Response to preflight request doesn't pass access control check: No 'Access-Control-Allow-Origin' header is present on the requested resource. Origin 'example.com' is therefore not allowed access.

This is a generic response that means your Elixir server is not allowing the CORS request. Most likely this is because of one of two things:

1. **The server doesn't recognize the origin (the browser's current URL) as an allowed origin.** Check the `origins:` option on the Plug or Router function, and make sure it allows whatever site the browser is trying do the CORS for. For example, if you are running a local javascript app on `localhost:8100`, then the `origins:` option must contain `localhost:8100` (or "\*" to allow anything).
2. **The server doesn't allow the headers that the client is requesting.** The client/browser can ask to use certain headers in the `Allow-Control-Request-Headers` header on the preflight request. This would be something like `content-type` or `accepts`. The server (ie. Corsica) must respond to the preflight request and allow those headers by specifying them in the response's `Access-Control-Allow-Headers` header.  You can use the `allow_headers:` option on the Plug or the Router function to do this.


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

[image]: http://i.imgur.com/n2DZpEU.jpg
[docs]: https://hexdocs.pm/corsica
[cors-wiki]: http://en.wikipedia.org/wiki/Cross-origin_resource_sharing
[cors-spec]: http://www.w3.org/TR/cors
[plug]: https://github.com/elixir-lang/plug
