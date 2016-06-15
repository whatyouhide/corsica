defmodule Corsica do
  @default_opts [
    origins: "*",
    allow_methods: ~w(HEAD GET POST PUT PATCH DELETE),
    allow_headers: ~w(),
    allow_credentials: false,
  ]

  @moduledoc """
  Plug-based swiss-army knife for CORS requests.

  Corsica provides facilities for dealing with
  [CORS](http://en.wikipedia.org/wiki/Cross-origin_resource_sharing) requests
  and responses. It provides:

    * low-level functions that let you decide when and where to deal with CORS
      requests and CORS response headers;
    * a plug that handles CORS requests and responds to preflight requests;
    * a router that can be used in your modules in order to turn them into CORS
      handlers which provide fine control over dealing with CORS requests.

  ## How it works

  Corsica is compliant with the [W3C CORS
  specification](http://www.w3.org/TR/cors/). As per this specification, Corsica
  doesn't put any CORS response headers in a connection that holds an invalid
  CORS request. To know what "invalid" CORS request means, have a look at the
  "Validity of CORS requests" section below.

  When some options that are not mandatory and have no default value (such
  `:max_age`) are not passed to Corsica (in one of the available ways to pass
  options to it), the relative header will often not be sent at all. This is
  compliant with the specification and at the same time it reduces the size of
  the response, even if just by a handful of bytes.

  The following is a list of all the CORS response headers supported by Corsica:

    * `Access-Control-Allow-Origin`
    * `Access-Control-Allow-Methods`
    * `Access-Control-Allow-Headers`
    * `Access-Control-Allow-Credentials`
    * `Access-Control-Expose-Headers`
    * `Access-Control-Max-Age`

  ## Using Corsica as a plug

  When `Corsica` is used as a plug, it intercepts all requests; it only sets a
  bunch of CORS headers for regular CORS requests, but it responds (with a `200 OK`
  and the appropriate headers) to preflight requests.

  If you want to use `Corsica` as a plug, be sure to plug it in your plug
  pipeline **before** any router: routers like `Plug.Router` (or
  `Phoenix.Router`) respond to HTTP verbs as well as request urls, so if
  `Corsica` is plugged after a router then preflight requests (which are
  `OPTIONS` requests) will often result in 404 errors since no route responds to
  them.

      defmodule MyApp.Endpoint do
        plug Head
        plug Corsica, max_age: 600, origins: "*", expose_headers: ~w(X-Foo)
        plug MyApp.Router
      end

  ## Using Corsica as a router generator

  When `Corsica` is used as a plug, it doesn't provide control over which urls
  are CORS-enabled or with which options. In order to do that, you can use
  `Corsica.Router`. See the documentation for `Corsica.Router` for more
  information.

  ## Origins

  Allowed origins can be specified by passing the `:origins` options either when
  using a Corsica-based router or when plugging `Corsica` in a plug pipeline.

  `:origins` can be a single value or a list of values. `"*"` can only appear as
  a single value. The default value is `#{inspect @default_opts[:origins]}`.
  The origin of a request (specified by the `"origin"` request header) will be
  considered a valid origin if it "matches" at least one of the origins
  specified in `:origins`. What "matches" means depends on the type of
  origin. Origins can be:

    * strings - the actual origin and the allowed origin have to be identical
    * regexes - the actual origin has to match the allowed regex (as per
      `Regex.match?/2`)
    * `{module, function}` tuples - `module.function` is called with the actual
      origin as its only argument; if it returns `true` the origin is accepted,
      if it returns `false` the origin is not accepted

  For example:

      # Matches everything
      plug Corsica, origins: "*"

      # Matches one of the given origins
      plug Corsica, origins: ["http://foo.com", "http://bar.com"]

      # Matches the given regex
      plug Corsica, origins: ~r{^https?://(.*\.?)foo\.com$}

  ### The value of the "access-control-allow-origin" header

  The `:origins` option directly influences the value of the
  `access-control-allow-origin` response header. When `:origins` is `"*"`, the
  `access-control-allow-origin` header is set to `*` as well. If the request's
  origin is allowed and `:origins` is something different than `"*"`, then you
  won't see that value as the value of the `access-control-allow-origin` header:
  the value of this header will be the request's origin (which is *mirrored*).
  This behaviour is intentional: it's compliant with the W3C CORS specification
  and at the same time it provides the advantage of "hiding" all the allowed
  origins from the client (which only sees its origin as an allowed origin).

  ## The "vary" header

  If `:origins` is a list with more than one value and the request origin
  matches, then a `Vary: Origin` header is added to the response.

  ## Options

  Besides `:origins`, the options that can be passed to the `use` macro, to
  `Corsica.Router.resource/2` and to the `Corsica` plug (along with their default
  values) are:

    * `:allow_headers` - a list of headers (as binaries). Sets the value of
      the `access-control-allow-headers` header used with preflight requests.
      Defaults to `#{inspect @default_opts[:allow_headers]}` (no headers are
      allowed).
    * `:allow_methods` - is a list of HTTP methods (as binaries). Sets the value
      of the `access-control-allow-methods` header used with preflight requests.
      Defaults to `#{inspect @default_opts[:allow_methods]}`.
    * `:allow_credentials` - is a boolean. If `true`, sends the
      `access-control-allow-credentials` with value `true`. If `false`, prevents
      that header from being sent at all. If `:origins` is set to `"*"` and
      `:allow_credentials` is set to `true`, then the value of the
      `access-control-allow-origin` header will always be the value of the
      `origin` request header (as per the W3C CORS specification) and not `*`.
      Defaults to `#{inspect @default_opts[:allow_credentials]}`.
    * `:expose_headers` - is a list of headers (as binaries). Sets the value of
      the `access-control-expose-headers` response header. This option *does
      not* have a default value; if it's not provided, the
      `access-control-expose-headers` header is not sent at all.
    * `:max_age` - is an integer or a binary. Sets the value of the
      `access-control-max-age` header used with preflight requests. This option
      *does not* have a default value; if it's not provided, the
      `access-control-max-age` header is not sent at all.
    * `:log` - see the "Logging" section below.

  ## Responding to preflight requests

  When the request is a preflight request and a valid one (valid origin, valid
  request method, and valid request headers), Corsica directly sends a response
  to that request instead of just adding headers to the connection (so that a
  possible plug pipeline can continue). To do this, Corsica **halts the
  connection** (through `Plug.Conn.halt/1`) and **sends a response**.

  ## Validity of CORS requests

  "Invalid CORS request" can mean that a request doesn't have an `Origin` header
  (so it's not a CORS request at all) or that it's a CORS request but:

    * the `Origin` request header doesn't match any of the allowed origins
    * the request is a preflight request but it requests to use a method or
      some headers that are not allowed (via the `Access-Control-Request-Method`
      and `Access-Control-Request-Headers` headers)

  ## Logging

  Corsica supports basic logging functionalities; it can log whether a CORS
  request is a valid one, what CORS headers are added to a response and similar
  information. Corsica distinguishes between three "types" of logs:

    * "rejected" logs, for when the request is "rejected" in the CORS perspective,
      e.g., it's not allowed
    * "invalid" logs, for when the request is not a simple CORS request or not a
      CORS preflight request
    * "accepted" logs, for when the request is a valid and accepted CORS request

  It's possible to configure these logs with the `:log` option, which is a
  keyword list with the `:rejected`, `:invalid`, and `:accepted` options. These
  options specify the logging level of each type of log. The defaults are:

    * `rejected: :warn`
    * `invalid: :debug`
    * `accepted: :debug`

  For example:

      plug Corsica, log: [rejected: :error]

  `false` can be used as the value of a level for a log type to suppress that
  type completely.

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
  # http://www.w3.org/TR/cors/#resource-implementation
  # > [...] [authors] should send a Vary: Origin HTTP header or provide other
  # > appropriate control directives to prevent caching of such responses, which
  # > may be inaccurate if re-used across-origins.
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

  import Plug.Conn

  alias Plug.Conn

  require Logger

  @behaviour Plug

  # Plug callbacks.

  def init(opts) do
    default_log = [
      rejected: :warn,
      invalid: :debug,
      accepted: :debug,
    ]

    opts
    |> Keyword.put(:log, Keyword.merge(default_log, opts[:log] || []))
    |> sanitize_opts()
  end

  def call(%Conn{} = conn, {:sanitized, _} = opts) do
    cond do
      not cors_req?(conn)      -> conn
      not preflight_req?(conn) -> put_cors_simple_resp_headers(conn, opts)
      true                     -> send_preflight_resp(conn, opts)
    end
  end

  # Public so that it can be called from `Corsica.Router` (and for testing too).
  @doc false
  def sanitize_opts({:sanitized, _} = opts) do
    opts
  end

  def sanitize_opts(opts) do
    opts = Keyword.merge(@default_opts, opts)

    opts =
      if opts[:max_age] do
        Keyword.update!(opts, :max_age, &to_string/1)
      else
        opts
      end

    opts =
      if opts[:expose_headers] do
        Keyword.update!(opts, :expose_headers, &Enum.join(&1, ", "))
      else
        opts
      end

    opts =
      opts
      |> Keyword.update!(:allow_methods, fn(m) -> Enum.map(m, &String.upcase/1) end)
      |> Keyword.update!(:allow_headers, fn(h) -> Enum.map(h, &String.downcase/1) end)

    {:sanitized, opts}
  end

  # Utilities

  @doc """
  Checks whether a given connection holds a CORS request.

  This function doesn't check if the CORS request is a *valid* CORS request: it
  just checks that it's a CORS request, that is, it has an `Origin` request
  header.
  """
  @spec cors_req?(Conn.t) :: boolean
  def cors_req?(%Conn{} = conn), do: get_req_header(conn, "origin") != []

  @doc """
  Checks whether a given connection holds a preflight CORS request.

  This function doesn't check that the preflight request is a *valid* CORS
  request: it just checks that it's a preflight request. A request is considered
  to be a CORS preflight request if and only if its request method is `OPTIONS`
  and it has a `Access-Control-Request-Method` request header.

  Note that if a request is a valid preflight request, that makes it a valid
  CORS request as well. You can thus call just `preflight_req?/1` instead of
  `preflight_req?/1` and `cors_req?/1`.
  """
  @spec preflight_req?(Conn.t) :: boolean
  def preflight_req?(%Conn{method: "OPTIONS"} = conn),
    do: cors_req?(conn) and get_req_header(conn, "access-control-request-method") != []
  def preflight_req?(%Conn{}),
    do: false

  # Request handling

  @doc """
  Sends a CORS preflight response regardless of the request being a valid CORS
  request or not.

  This function assumes nothing about `conn`. If it's a valid CORS preflight
  request with an allowed origin, CORS headers are set by calling
  `put_cors_preflight_resp_headers/2` and the response **is sent** with status
  `status` and body `body`. `conn` is **halted** before being sent.

  The response is always sent because if the request is not a valid CORS
  request, then no CORS headers will be added to the response. This behaviour
  will be interpreted by the browser as a non-allowed preflight request, as
  expected.

  For more information on what headers are sent with the response if the
  preflight request is valid, look at the documentation for
  `put_cors_preflight_resp_headers/2`.

  ## Options

  This function accepts the same options accepted by the `Corsica` plug
  (described in the documentation for the `Corsica` module), including `:log`
  for logging.

  ## Examples

  This function could be used to manually build a plug that responds to
  preflight requests. For example:

      defmodule MyRouter do
        use Plug.Router
        plug :match
        plug :dispatch

        options "/foo",
          do: Corsica.send_preflight_resp(conn, origins: "*")
        get "/foo",
          do: send_resp(conn, 200, "ok")
      end

  """
  def send_preflight_resp(%Conn{} = conn, status \\ 200, body \\ "", opts) do
    conn
    |> put_cors_preflight_resp_headers(opts)
    |> halt()
    |> send_resp(status, body)
  end

  @doc """
  Adds CORS response headers to a simple CORS request to `conn`.

  This function assumes nothing about `conn`. If `conn` holds an invalid CORS
  request or a request whose origin is not allowed, `conn` is returned
  unchanged; the absence of CORS headers will be interpreted as an invalid CORS
  response by the browser (according to the W3C spec).

  If the CORS request is valid, the following response headers are set:

    * `Access-Control-Allow-Origin`

  and the following headers are optionally set (if the corresponding option is
  present):

    * `Access-Control-Expose-Headers` (if the `:expose_headers` option is
      present)
    * `Access-Control-Allow-Credentials` (if the `:allow_credentials` option is
      `true`)

  ## Options

  This function accepts the same options accepted by the `Corsica` plug
  (described in the documentation for the `Corsica` module), including `:log`
  for logging.

  ## Examples

      conn
      |> put_cors_simple_resp_headers(origins: "*", allow_credentials: true)
      |> send_resp(200, "Hello!")

  """
  def put_cors_simple_resp_headers(%Conn{} = conn, opts) do
    opts = sanitize_opts(opts)

    cond do
      not cors_req?(conn) ->
        log :invalid, opts, "Request is not a CORS request because there is no Origin header"
        conn
      not allowed_origin?(conn, opts) ->
        log :rejected, opts, "Simple CORS request from Origin '#{origin(conn)}' is not allowed"
        conn
      true ->
        log :accepted, opts, "Simple CORS request from Origin '#{origin(conn)}' is allowed"
        conn
        |> put_common_headers(opts)
        |> put_expose_headers_header(opts)
    end
  end

  @doc """
  Adds CORS response headers to a preflight request to `conn`.

  This function assumes nothing about `conn`. If `conn` holds an invalid CORS
  request or an invalid preflight request, then `conn` is returned unchanged;
  the absence of CORS headers will be interpreted as an invalid CORS response by
  the browser (according to the W3C spec).

  If the request is a valid CORS request, the following headers will be added to
  the response:

    * `Access-Control-Allow-Origin`
    * `Access-Control-Allow-Methods`
    * `Access-Control-Allow-Headers`

  and the following headers will optionally be added (based on the value of the
  corresponding options):

    * `Access-Control-Allow-Credentials` (if the `:allow_credentials` option is
      `true`)
    * `Access-Control-Max-Age` (if the `:max_age` option is present)

  ## Options

  This function accepts the same options accepted by the `Corsica` plug
  (described in the documentation for the `Corsica` module), including `:log`
  for logging.

  ## Examples

      put_cors_preflight_resp_headers conn, [
        max_age: 86400,
        allow_headers: ~w(X-Header),
        origins: ~r/\w+\.foo\.com$/
      ]

  """
  def put_cors_preflight_resp_headers(%Conn{} = conn, opts) do
    opts = sanitize_opts(opts)

    cond do
      not preflight_req?(conn) ->
        log :invalid, opts, "Request is not a preflight CORS request (has no Origin header," <>
                            " it's not OPTIONS or has no access-control-request-method header"
        conn
      not allowed_origin?(conn, opts) ->
        log :rejected, opts, "Origin '#{origin(conn)}' not allowed, preflight CORS request is not valid"
        conn
      not allowed_preflight?(conn, opts) ->
        conn
      true ->
        log :accepted, opts, "Preflight CORS request from Origin '#{origin(conn)}' is allowed"
        conn
        |> put_common_headers(opts)
        |> put_allow_methods_header(opts)
        |> put_allow_headers_header(opts)
        |> put_max_age_header(opts)
    end
  end

  defp put_common_headers(conn, {:sanitized, opts} = sanitized) do
    conn
    |> put_allow_credentials_header(sanitized)
    |> put_allow_origin_header(sanitized)
    |> update_vary_header(opts[:origins])
  end

  defp put_allow_credentials_header(conn, {:sanitized, opts}) do
    if opts[:allow_credentials] do
      put_resp_header(conn, "access-control-allow-credentials", "true")
    else
      conn
    end
  end

  defp put_allow_origin_header(conn, {:sanitized, opts}) do
    actual_origin = conn |> get_req_header("origin") |> hd()
    allowed_origins = Keyword.fetch!(opts, :origins)

    # '*' cannot be used as the value of the `Access-Control-Allow-Origins`
    # header if `Access-Control-Allow-Credentials` is true.
    value =
      if allowed_origins == "*" and not opts[:allow_credentials] do
        "*"
      else
        actual_origin
      end

    put_resp_header(conn, "access-control-allow-origin", value)
  end

  # Only update the Vary header if the origin is not a binary (it could be a
  # regex or a function) or if there's a list of more than one origins.
  defp update_vary_header(conn, origin) when is_binary(origin),
    do: conn
  defp update_vary_header(conn, [origin]) when is_binary(origin),
    do: conn
  defp update_vary_header(conn, _origin),
    do: %{conn | resp_headers: [{"vary", "origin"} | conn.resp_headers]}

  defp put_allow_methods_header(conn, {:sanitized, opts}) do
    value = opts |> Keyword.fetch!(:allow_methods) |> Enum.join(", ")
    put_resp_header(conn, "access-control-allow-methods", value)
  end

  defp put_allow_headers_header(conn, {:sanitized, opts}) do
    value = opts |> Keyword.fetch!(:allow_headers) |> Enum.join(", ")
    put_resp_header(conn, "access-control-allow-headers", value)
  end

  defp put_max_age_header(conn, {:sanitized, opts}) do
    if max_age = opts[:max_age] do
      put_resp_header(conn, "access-control-max-age", max_age)
    else
      conn
    end
  end

  defp put_expose_headers_header(conn, {:sanitized, opts}) do
    expose_headers = opts[:expose_headers]
    if expose_headers && expose_headers != "" do
      put_resp_header(conn, "access-control-expose-headers", expose_headers)
    else
      conn
    end
  end

  # Made public since this function is only called by macros as of now, and so
  # an 'unused function' warning is issued if the macros produce no code.
  @doc false
  def origin(conn) do
    conn |> get_req_header("origin") |> List.first()
  end

  # Made public for testing
  @doc false
  def allowed_origin?(conn, {:sanitized, opts}) do
    [origin | _] = get_req_header(conn, "origin")
    do_allowed_origin?(opts[:origins], origin)
  end

  defp do_allowed_origin?("*", _origin),
    do: true
  defp do_allowed_origin?(allowed_origins, origin),
    do: Enum.any?(List.wrap(allowed_origins), &matching_origin?(&1, origin))

  defp matching_origin?(origin, origin),
    do: true
  defp matching_origin?(allowed, _actual) when is_binary(allowed),
    do: false
  defp matching_origin?(%Regex{} = allowed, actual),
    do: Regex.match?(allowed, actual)
  defp matching_origin?({module, function}, actual) when is_atom(module) and is_atom(function),
    do: apply(module, function, [actual])

  # Made public for testing.
  @doc false
  def allowed_preflight?(conn, {:sanitized, opts}) do
    allowed_request_method?(conn, opts) and allowed_request_headers?(conn, opts)
  end

  defp allowed_request_method?(conn, opts) do
    # We can safely assume there's an Access-Control-Request-Method header
    # otherwise the request wouldn't have been identified as a preflight
    # request.
    req_method = conn |> get_req_header("access-control-request-method") |> hd()
    allowed? = req_method in opts[:allow_methods]

    if not allowed? do
      log :rejected, opts, "Invalid preflight CORS request because the req method is not in :allow_methods"
    end

    allowed?
  end

  defp allowed_request_headers?(conn, opts) do
    allowed_headers = opts[:allow_headers]
    non_allowed_header =
      conn
      |> get_req_header("access-control-request-headers")
      |> Enum.flat_map(&(&1 |> String.downcase() |> Plug.Conn.Utils.list()))
      |> Enum.find(&not(&1 in allowed_headers))

    if non_allowed_header do
      log :rejected, opts, "Invalid preflight CORS request because the header #{inspect non_allowed_header} is not in :allow_headers"
    end

    # If there's no non_allowed_header, then they're all allowed.
    is_nil(non_allowed_header)
  end

  defp log(type, {:sanitized, opts}, what) do
    log(type, opts, what)
  end

  defp log(type, opts, what) when is_list(opts) and type in [:invalid, :rejected, :accepted] do
    if level = get_in(opts, [:log, type])  do
      Logger.log(level, what)
    end
  end
end
