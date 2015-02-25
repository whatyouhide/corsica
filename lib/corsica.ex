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
      origins are accepted. Origins can be specified either as strings or as
      regexes. The default value is `"*"`.
    * `:allow_headers` - is a list of headers. Sets the value of the
      `access-control-allow-headers` header used with preflight requests.
      Defaults to `[]` (no headers are allowed).
    * `:allow_methods` - is a list of HTTP methods (as binaries). Sets the value
      of the `access-control-allow-methods` header used with preflight requests.
      Defaults to `[]` (no methods are allowed).
    * `:allow_credentials` - is a boolean. If `true`, sends the
      `access-control-allow-credentials` with value `true`. If `false`, prevents
      that header from being sent at all. Defaults to `false`. Note that an
      `ArgumentError` exception is raised in case the `:allow_credentials`
      options is set to `true` *and* the `:origins` option is set to `"*"`.
    * `:expose_headers` - is a list of headers (as binaries). Sets the value of
      the `access-control-expose-headers` response header. This option doesn't
      have a default value; if it's not provided, the
      `access-control-expose-headers` header is not sent at all.
    * `:max_age` - is an integer or a binary. Sets the value of the
      `access-control-max-age` header used with preflight requests. This option
      doesn't have a default value; if it's not provided, the
      `access-control-max-age` header is not sent at all.

  The `access-control-allow-origin` header has a particular behaviour since it's
  dynamically set based on the value of the `Origin` request header. It works as
  follows:

    * if `:origins` is `"*"`, the value of the `access-control-allow-origin`
      header is set to `*` regardless of the value of the `Origin` request
      header;
    * if the given `Origin` matches one of the origins given in `:origins`, than
      the `access-control-allow-origin` header is set to the value of the
      `Origin` request header (it "mirrors" it so that it doesn't reveal any
      other allowed origin to the client);
    * if the given `Origin` doesn't match any origins in `:origins`, then the
      `access-control-allow-origin` header is set to the first origin in
      `:origins`. This behaviour can be overridden through the `:allow_origin`
      option, which specifies exactly what the value of
      `access-control-allow-origin` should be in case the origin doesn't match
      any allowed origin.

  When used as a plug, Corsica supports the additional `:resources` options,
  which is a list of resources exactly like the ones passed to the
  `Corsica.DSL.resources/2` macro. By default, this option is not present,
  meaning that all resources are CORS-enabled.

  """

  # Here are some nice (and apparently overlooked!) quotes from the W3C CORS
  # specification.
  #
  # http://www.w3.org/TR/cors/#access-control-allow-credentials-response-header
  # The syntax of the Access-Control-Allow-Credentials header only accepts the
  # value "true" (without quotes, case-sensitive). Any other value is not
  # conforming to the official CORS specification (many libraries tend to just
  # shove the value of a boolean in that header, so it happens to have the value
  # "false" as well).
  #
  # http://www.w3.org/TR/cors/#resource-requests, item 3.
  # The string "*" cannot be used [as the value for the
  # Access-Control-Allow-Origin] header for a resource that supports
  # credentials.
  #
  # http://www.w3.org/TR/cors/#resource-preflight-requests, item 9.
  # If method is a simple method, [setting the Access-Control-Allow-Methods
  # header] may be skipped (but it is not prohibited).
  # Simply returning the method indicated by Access-Control-Request-Method (if
  # supported) can be enough.
  #
  # http://www.w3.org/TR/cors/#resource-preflight-requests, item 10.
  # If each of the header field names is a simple header and none is
  # Content-Type, [setting the Access-Control-Allow-Headers] may be
  # skipped. Simply returning supported headers from
  # Access-Control-Allow-Headers can be enough.
  #
  # http://www.w3.org/TR/cors/#resource-implementation
  # [...] [authors] should send a Vary: Origin HTTP header or provide other
  # appropriate control directives to prevent caching of such responses, which
  # may be inaccurate if re-used across-origins.


  import Plug.Conn
  alias Corsica.Preflight
  alias Corsica.Actual
  alias Corsica.Helpers

  @default_opts [
    origins: "*",
    allow_headers: ~w(),
    allow_methods: ~w(),
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
  @spec sanitize_opts([Keyword.t]) :: [Keyword.t]
  def sanitize_opts(opts) do
    import String, only: [upcase: 1, downcase: 1]
    import Enum, only: [map: 2]

    wrap = fn
      "*" -> "*"
      val -> List.wrap(val)
    end

    Keyword.merge(@default_opts, opts)
    |> Keyword.update!(:allow_methods, fn(m) -> map(m, &upcase/1) end)
    |> Keyword.update!(:allow_headers, fn(h) -> map(h, &downcase/1) end)
    |> Keyword.update!(:origins, wrap)
    |> validate_credentials_with_wildcard_origin!
  end

  @spec validate_credentials_with_wildcard_origin!([Keyword.t]) :: [Keyword.t]
  defp validate_credentials_with_wildcard_origin!(opts) do
    if Keyword.fetch!(opts, :origins) == "*" and Keyword.fetch!(opts, :allow_credentials) do
      raise ArgumentError, "credentials can't be allowed when the allowed origins are *"
    else
      opts
    end
  end


  # Request handlers.

  @doc """
  """
  @spec handle_req(Plug.Conn.t, [Keyword.t]) :: Plug.Conn.t
  def handle_req(conn, opts) do
    require Logger
    # Logger.debug "Corsica intercepted the request"
    if preflight_request?(conn) do
      Preflight.handle_req(conn, opts)
    else
      Actual.handle_req(conn, opts)
    end
  end

  @doc """
  Returns `true` if the given connection holds a CORS request, `false`
  otherwise.

  A request is considered a CORS request if and only if it has an `Origin`
  header.

  ## Examples

      cors_request?(conn)

  """
  @spec cors_request?(Plug.Conn.t) :: boolean
  def cors_request?(conn),
    do: Plug.Conn.get_req_header(conn, "origin") != []

  @doc """
  Returns `true` if the given connection holds a preflight request, `false`
  otherwise.

  A request is considered to be a preflight request if it's an `OPTIONS` request
  and has an `Access-Control-Request-Method` header.

  ## Examples

      preflight_request?(conn)

  """
  @spec preflight_request?(Plug.Conn.t) :: boolean
  def preflight_request?(%Plug.Conn{method: "OPTIONS"} = conn),
    do: get_req_header(conn, "access-control-request-method") != []
  def preflight_request?(%Plug.Conn{}),
    do: false


  @doc false
  @spec put_common_headers(Plug.Conn.t, [Keyword.t]) :: Plug.Conn.t
  def put_common_headers(conn, opts) do
    conn
    |> put_allow_origin_header(opts)
    |> put_allow_credentials_header(opts)
  end

  @spec put_allow_origin_header(Plug.Conn.t, [Keyword.t]) :: Plug.Conn.t
  defp put_allow_origin_header(conn, opts) do
    allowed_origins = Keyword.fetch!(opts, :origins)
    origin          = conn |> get_req_header("origin") |> hd

    header = allow_origin_header(allowed_origins, origin, opts[:allow_origin])

    if header != "*" and allowed_origins != "*" and length(allowed_origins) > 1 do
      conn = add_origin_to_vary_header(conn)
    end

    put_resp_header(conn, "access-control-allow-origin", header)
  end

  @spec allow_origin_header(String.t | [String.t | Regex.t],
                            String.t,
                            String.t | nil) :: String.t
  defp allow_origin_header("*", _origin, _custom), do: "*"
  defp allow_origin_header(allowed_origins, origin, custom) do
    if Enum.find(allowed_origins, &matching_origin?(&1, origin)) do
      origin
    else
      custom || hd(allowed_origins)
    end
  end

  @spec matching_origin?(String.t | Regex.t, String.t) :: boolean
  defp matching_origin?(origin, origin),
    do: true
  defp matching_origin?(allowed, _origin) when is_binary(allowed),
    do: false
  defp matching_origin?(allowed, origin),
    do: Regex.match?(allowed, origin)

  @spec add_origin_to_vary_header(Plug.Conn.t) :: Plug.Conn.t
  defp add_origin_to_vary_header(conn) do
    existing = (get_resp_header(conn, "vary") |> List.first) || ""
    existing = Plug.Conn.Utils.list(existing)
    if existing && not "origin" in existing do
      put_resp_header(conn, "vary", Enum.join(["origin"|existing], ", "))
    else
      put_resp_header(conn, "vary", "origin")
    end
  end

  @spec put_allow_credentials_header(Plug.Conn.t, [Keyword.t]) :: Plug.Conn.t
  defp put_allow_credentials_header(conn, opts) do
    if opts[:allow_credentials] do
      put_resp_header(conn, "access-control-allow-credentials", "true")
    else
      conn
    end
  end
end
