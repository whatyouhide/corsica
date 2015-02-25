# Corsica

Corsica is a plug and a DSL for handling [CORS][cors-wiki] requests.
[Documentation can be found online][docs].

![Nice Corsica pic][image]
*(I had to include a nice pic because, let's be honest, CORS requests aren't the
most fun thing in the world, are they?)*

## Features

* Ignores requests without an `Origin` header (yay, performance!)
* Handles preflight requests, including invalid requests where the request
    method or the request headers are not allowed
* Compiles CORS-enabled resources into functions based on pattern-matching in
    order to take advantage of the optimizations made by the VM (yay, double
    performance!)
* Is compliant with the [CORS specification][cors-spec] defined by the W3C.

## Usage

The `Corsica` module can be used both as a stand-alone plug:

```elixir
defmodule MyApp.Endpoint do
  plug Corsica,
    origins: ["http://foo.com"],
    max_age: 600,
    allow_headers: ~w(X-Header),
    allow_methods: ~w(GET POST),
    expose_headers: ~w(Content-Type)

  plug Plug.Session
  plug :router
end
```

as well as a *plug generator*. Using it as a plug generator allows for finer
control over the options and the headers of CORS responses; using the `Corsica`
module in an arbitrary module automatically makes that module a plug that can be
used in your application.

```elixir
defmodule MyApp.CORS do
  use Corsica,
    origins: "*",
    max_age: 600,
    allow_headers: ~w(X-My-Header)

  resources ["/foo", "/bar"], allow_methods: ~w(PUT PATCH)

  resources ["/users"],
    allow_credentials: true,
    allow_methods: ~w(HEAD GET POST PUT PATCH DELETE)
end

# MyApp.CORS can now be used as a regular plug.
defmodule MyApp.Endpoint do
  plug MyApp.CORS
  plug :router
end
```

This is only a short overview of what Corsica can do; for more detailed
information and for a reference on the methods and options that can be used with
Corsica, refer to the [online documentation][docs].

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
