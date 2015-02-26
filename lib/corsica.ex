defmodule Corsica do
  @moduledoc """
  Plug and DSL for handling CORS requests.

  Corsica provides facilites for working with
  [CORS](http://en.wikipedia.org/wiki/Cross-origin_resource_sharing) in
  Plug-based applications.

  Corsica is (well, tries to be!) compliant with the [CORS specification defined
  by the W3C](http://www.w3.org/TR/cors/#redirect-steps).

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

  ## Options

  The options that can be passed to the `use` macro, to `Corsica.DSL.resource/2`
  and to the `Corsica` plug (along with their default values) are:

    * `:origins` - is a single value or a list of values. It specifies which
      origins are accepted. `"*"` can only appear as a single value and not in
      a list of valid origins. Origins can be specified either as strings or as
      regexes. The default value is `"*"`.
    * `:allow_headers` - is a list of headers. Sets the value of the
      `access-control-allow-headers` header used with preflight requests.
      Defaults to `[]` (no headers are allowed).
    * `:allow_methods` - is a list of HTTP methods (as binaries). Sets the value
      of the `access-control-allow-methods` header used with preflight requests.
      Defaults to `[]` (no methods are allowed).
    * `:allow_credentials` - is a boolean. If `true`, sends the
      `access-control-allow-credentials` with value `true`. If `false`, prevents
      that header from being sent at all. If `:origins` is set to `"*"` and
      `:allow_credentials` is set to `true`, than the value of the
      `access-control-allow-origin` header will always be the value of the `origin`
      request header (as per the W3C CORS specification) and not `*`.
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

  ### Vary header

  If `:origins` is a list with more than one value and the request origin matches,
  then a `Vary: Origin` header is added to the response.

  ### Preflight requests

  When the request is a preflight request and a valid one (valid origin, valid request
  method and valid request headers), Corsica directly sends a response to that request
  instead of just adding headers to the connection (so that a possible plug pipeline
  can continue). To do this, Corsica halts the connection (through `Plug.Conn.halt/1`)
  and sends a 200 OK response with a body of `""`.

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
  alias Corsica.Simple
  alias Corsica.Helpers

  @default_opts [
    origins: "*",
    allow_methods: ~w(),
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

  def sanitize_opts(opts) do
    import Enum, only: [map: 2]

    wrap_origins = fn
      "*" -> "*"
      any -> List.wrap(any)
    end

    Keyword.merge(@default_opts, opts)
    |> Keyword.update!(:origins, wrap_origins)
    |> Keyword.update!(:allow_methods, fn(m) -> map(m, &String.upcase/1) end)
    |> Keyword.update!(:allow_headers, fn(h) -> map(h, &String.downcase/1) end)
    |> maybe_cast_max_age
  end

  defp maybe_cast_max_age(opts) do
    if opts[:max_age] do
      Keyword.update!(opts, :max_age, &to_string/1)
    else
      opts
    end
  end

  def cors_request?(conn),
    do: get_origin(conn) != nil

  def preflight_request?(%Plug.Conn{method: "OPTIONS"} = conn),
    do: get_req_header(conn, "access-control-request-method") != []
  def preflight_request?(%Plug.Conn{}),
    do: false

  # Request handling.

  def handle_req(conn, opts) do
    if allowed_origin?(opts[:origins], get_origin(conn)) do
      simple_or_preflight(conn, opts)
    else
      conn
    end
  end

  defp allowed_origin?("*", _origin), do: true
  defp allowed_origin?(allowed_origins, origin) do
    matching_origin? = fn
      origin, origin -> true
      allowed, _origin when is_binary(allowed) -> false
      allowed, origin -> Regex.match?(allowed, origin)
    end

    Enum.any?(allowed_origins, &matching_origin?.(&1, origin))
  end

  defp simple_or_preflight(conn, opts) do
    mod = if preflight_request?(conn), do: Preflight, else: Simple
    mod.handle_req(conn, opts)
  end

  defp get_origin(conn) do
    conn |> get_req_header("origin") |> List.first
  end

  def put_common_headers(conn, opts) do
    conn
    |> put_allow_credentials_header(opts)
    |> put_allow_origin_header(opts)
    |> update_vary_header(opts)
  end

  defp put_allow_credentials_header(conn, opts) do
    if opts[:allow_credentials] do
      put_resp_header(conn, "access-control-allow-credentials", "true")
    else
      conn
    end
  end

  defp put_allow_origin_header(conn, opts) do
    actual_origin = get_origin(conn)
    allowed_origins = Keyword.fetch!(opts, :origins)

    value = if allowed_origins == "*" and not opts[:allow_credentials] do
              "*"
            else
              actual_origin
            end
    put_resp_header(conn, "access-control-allow-origin", value)
  end

  defp update_vary_header(conn, opts) do
    allowed_origins = Keyword.fetch!(opts, :origins)
    if allowed_origins != "*" and length(allowed_origins) > 1 do
      update_in conn.resp_headers, fn(current) -> [{"vary", "origin"}|current] end
    else
      conn
    end
  end
end
