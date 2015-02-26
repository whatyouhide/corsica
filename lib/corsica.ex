defmodule Corsica do
  @moduledoc """
  Plug and DSL for handling CORS requests.

  Corsica provides facilites for working with
  [CORS](http://en.wikipedia.org/wiki/Cross-origin_resource_sharing) in
  Plug-based applications. It is (well, tries to be!) compliant with the [CORS
  specification defined by the W3C](http://www.w3.org/TR/cors/).

  Corsica can be used in two ways:

    * as a generator for fine-tuned plugs
    * as a stand-alone plug

  ## Generator

  The `Corsica` module can be used in any module in order to turn that module
  into a plug that handles CORS request. This is useful if there are a lot of
  different cases to handle (multiple origins, headers based on resources) since
  it gives fine control over the behaviour of the generated plug.

  A quick example may make this easier to understand:

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

  In the example above, the `MyApp.CORS` module becomes a valid plug since the
  `Corsica` module is used. The `resources/2` macro is used in order to declare
  resources (routes) for which the server should respond with CORS headers.
  Options passed to `resources/2` are used to set the values of the CORS
  headers (for more information on options, read the "Options" section); they
  override the global options that can be passed to the `use` macro, which apply
  to all declared resources.

  Given the example above, the `MyApp.CORS` plug can be used as follows:

      defmodule MyApp.Router do
        use Plug.Router
        plug MyApp.CORS
        plug :match
        plug :dispatch

        match _ do
          send_resp(conn, 200, "OK")
        end
      end

  For more information on declaring single resources, have a look at the
  `Corsica.DSL.resources/2` macro (which is imported when `Corsica` is used).

  ## Plug

  In its simplest form, Corsica can be used as a stand-alone plug too. This
  prevents from fine-tuning the CORS header on a per-resource basis, but it
  supports all other options supported by the plug generator and can be useful
  for simple CORS needs.

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

  ## Origins

  Allowed origins can be specified by passing the `:origins` options either when
  `Corsica` is used or when the `Corsica` plug is plugged to a pipeline.

  `:origins` can be a single value or a list of values. `"*"` can only appear as
  a single value. The default value is `"*"`. Origins can be specified either
  as:

    * strings - the allowed origin and the actual origin have to be identical
    * regexes - the actual origin has to match the allowed regex functions with
    * a type `(binary -> boolean)` - the function applied to the actual origin
      has to return `true`

  If `:origins` is a list with more than one value and the request origin
  matches, then a `Vary: Origin` header is added to the response.

  ## Options

  Besides `:origins`, the options that can be passed to the `use` macro, to
  `Corsica.DSL.resource/2` and to the `Corsica` plug (along with their default
  values) are:

    * `:allow_headers` - is a list of headers (as binaries). Sets the value of
      the `access-control-allow-headers` header used with preflight requests.
      Defaults to `[]` (no headers are allowed).
    * `:allow_methods` - is a list of HTTP methods (as binaries). Sets the value
      of the `access-control-allow-methods` header used with preflight requests.
      Defaults to `["HEAD", "GET", "POST", "PUT", "PATCH", "DELETE"]`.
    * `:allow_credentials` - is a boolean. If `true`, sends the
      `access-control-allow-credentials` with value `true`. If `false`, prevents
      that header from being sent at all. If `:origins` is set to `"*"` and
      `:allow_credentials` is set to `true`, than the value of the
      `access-control-allow-origin` header will always be the value of the
      `origin` request header (as per the W3C CORS specification) and not `*`.
    * `:expose_headers` - is a list of headers (as binaries). Sets the value of
      the `access-control-expose-headers` response header. This option doesn't
      have a default value; if it's not provided, the
      `access-control-expose-headers` header is not sent at all.
    * `:max_age` - is an integer or a binary. Sets the value of the
      `access-control-max-age` header used with preflight requests. This option
      doesn't have a default value; if it's not provided, the
      `access-control-max-age` header is not sent at all.

  When used as a plug, Corsica supports the additional `:resources` options,
  which is a list of resources exactly like the ones passed to the
  `Corsica.DSL.resources/2` macro. By default, this option is not present,
  meaning that all resources are CORS-enabled.

  ## Responding to preflight requests

  When the request is a preflight request and a valid one (valid origin, valid
  request method and valid request headers), Corsica directly sends a response
  to that request instead of just adding headers to the connection (so that a
  possible plug pipeline can continue). To do this, Corsica **halts the
  connection** (through `Plug.Conn.halt/1`) and **sends a 200 OK response** with
  a body of `""`.

  """

  # Here are some nice (and apparently overlooked!) quotes from the W3C CORS
  # specification, along with some thoughts around them.
  #
  # http://www.w3.org/TR/cors/#access-control-allow-credentials-response-header
  # The syntax of the Access-Control-Allow-Credentials header only accepts the
  # value "true" (without quotes, case-sensitive). Any other value is not
  # conforming to the official CORS specification (many libraries tend to just
  # shove the value of a boolean in that header, so it happens to have the value
  # "false" as well).
  #
  # http://www.w3.org/TR/cors/#resource-requests, item 3.
  # > The string "*" cannot be used [as the value for the
  # > Access-Control-Allow-Origin] header for a resource that supports
  # > credentials.
  #
  # http://www.w3.org/TR/cors/#resource-preflight-requests, item 9.
  # > If method is a simple method, [setting the Access-Control-Allow-Methods
  # > header] may be skipped (but it is not prohibited).
  # > Simply returning the method indicated by Access-Control-Request-Method (if
  # > supported) can be enough.
  # However, this behaviour can inhibit caching from the client side since the
  # client has to issue a preflight request for each method it wants to use,
  # while if all the allowed methods are returned every time then the cached
  # preflight request can be used more times.
  #
  # http://www.w3.org/TR/cors/#resource-preflight-requests, item 10.
  # > If each of the header field names is a simple header and none is
  # > Content-Type, [setting the Access-Control-Allow-Headers] may be
  # > skipped. Simply returning supported headers from
  # > Access-Control-Allow-Headers can be enough.
  # The same argument for Access-Control-Allow-Methods can be made here.
  #
  # http://www.w3.org/TR/cors/#resource-implementation
  # > [...] [authors] should send a Vary: Origin HTTP header or provide other
  # > appropriate control directives to prevent caching of such responses, which
  # > may be inaccurate if re-used across-origins.


  import Plug.Conn
  alias Corsica.Preflight
  alias Corsica.Common
  alias Corsica.Simple
  alias Corsica.Helpers

  @default_opts [
    origins: "*",
    allow_methods: ~w(HEAD GET POST PUT PATCH DELETE),
    allow_headers: ~w(),
    allow_credentials: false,
  ]

  @doc false
  defmacro __using__(opts) do
    quote do
      use Corsica.DSL, unquote(opts)
    end
  end

  @behaviour Plug

  def init(opts), do: sanitize_opts(opts)

  def call(%Plug.Conn{path_info: path_info} = conn, opts) do
    {routes, opts} = Keyword.pop(opts, :resources)
    cond do
      not cors_request?(conn)            -> conn
      !routes                            -> handle_req(conn, opts)
      matching_route?(path_info, routes) -> handle_req(conn, opts)
      true                               -> conn
    end
  end

  @spec matching_route?([String.t], [String.t]) :: boolean
  defp matching_route?(path_info, routes) do
    compiled = Enum.map(routes, &Helpers.compile_route/1)

    Enum.any? compiled, fn(route) ->
      Code.eval_quoted(quote do
        match?(unquote(route), unquote(path_info))
      end) |> elem(0)
    end
  end

  @doc false
  def sanitize_opts(opts) do
    import Enum, only: [map: 2]
    opts = Keyword.merge(@default_opts, opts)

    if opts[:max_age] do
      opts = Keyword.update!(opts, :max_age, &to_string/1)
    end

    opts
    |> Keyword.update!(:allow_methods, fn(m) -> map(m, &String.upcase/1) end)
    |> Keyword.update!(:allow_headers, fn(h) -> map(h, &String.downcase/1) end)
  end

  @doc """
  Checks whether a given connection holds a CORS request.

  It doesn't check if the CORS request is valid: it just checks that it's a CORS
  request. A request is a CORS request if and only if it has an `Origin` request
  header.
  """
  @spec cors_request?(Plug.Conn.t) :: boolean
  def cors_request?(conn),
    do: get_origin(conn) != nil

  @doc """
  Checks whether a given connection holds a CORS preflight request.

  Like `cors_request?/1`, it doesn't check that the preflight request is valid:
  it just checks that it's a preflight request. A CORS request is considered to
  be a preflight request if and only if it is an `OPTIONS` request and it has an
  `Access-Control-Request-Method` request header.

  Note that this function does not check if the given request is a CORS one. If
  you want to check for that too, use `cors_request?/1`.
  """
  @spec preflight_request?(Plug.Conn.t) :: boolean
  def preflight_request?(%Plug.Conn{method: "OPTIONS"} = conn),
    do: get_req_header(conn, "access-control-request-method") != []
  def preflight_request?(%Plug.Conn{}),
    do: false

  # Request handling.

  @doc false
  def handle_req(conn, opts) do
    invalid? = not(allowed_origin?(opts[:origins], get_origin(conn))) or
      (preflight_request?(conn) and not Preflight.valid?(conn, opts))

    if invalid? do
      conn
    else
      conn
      |> Common.put_common_headers(opts)
      |> simple_or_preflight(opts)
    end
  end

  defp allowed_origin?("*", _origin),
    do: true
  defp allowed_origin?(allowed_origins, origin)
    when is_list(allowed_origins),
    do: Enum.any?(allowed_origins, &matching_origin?(&1, origin))
  defp allowed_origin?(allowed_origin, origin),
    do: matching_origin?(allowed_origin, origin)

  defp matching_origin?(origin, origin),
    do: true
  defp matching_origin?(allowed, _actual) when is_binary(allowed),
    do: false
  defp matching_origin?(allowed, actual) when is_function(allowed),
    do: allowed.(actual)
  defp matching_origin?(allowed, actual),
    do: Regex.match?(allowed, actual)

  defp simple_or_preflight(conn, opts) do
    if preflight_request?(conn) do
      conn
      |> Preflight.put_preflight_headers(opts)
      |> halt
      |> send_resp(200, "")
    else
      conn
      |> Simple.put_simple_headers(opts)
    end
  end

  @compile {:inline, get_origin: 1}
  @doc false
  def get_origin(conn) do
    conn |> get_req_header("origin") |> List.first
  end
end
