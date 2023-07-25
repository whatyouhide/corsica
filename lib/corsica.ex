defmodule Corsica do
  @moduledoc """
  [Plug](https://github.com/elixir-plug/plug)-based swiss-army knife for CORS requests.

  Corsica provides facilities for dealing with
  [CORS](http://en.wikipedia.org/wiki/Cross-origin_resource_sharing) requests
  and responses. It provides:

    * low-level functions that let you decide when and where to deal with CORS
      requests and CORS response headers;
    * a **plug** that handles CORS requests and responds to preflight requests;
    * a **router** that can be used in your modules in order to turn them into CORS
      handlers which provide fine control over dealing with CORS requests.

  ## How It Works

  Corsica is compliant with the [W3C CORS
  specification](http://www.w3.org/TR/cors/). As per this specification, Corsica
  **doesn't put any CORS response headers** in a connection that holds an invalid
  CORS request. To know what "invalid" CORS request means, have a look at the
  [*Validity of CORS Requests* section](#module-validity-of-cors-requests) below.

  > #### Headers or No Headers? {: .warning}
  >
  > When some options that are not mandatory and have no default value (such as
  > `:max_age`) are not passed to Corsica, the relative header will often **not be sent**
  > at all. This is compliant with the specification, and at the same time it reduces the size of
  > the response, even if just by a handful of bytes.

  The following is a list of all the *CORS response headers* supported by Corsica:

    * `Access-Control-Allow-Origin`
    * `Access-Control-Allow-Methods`
    * `Access-Control-Allow-Headers`
    * `Access-Control-Allow-Credentials`
    * `Access-Control-Allow-Private-Network`
    * `Access-Control-Expose-Headers`
    * `Access-Control-Max-Age`
    * `Vary` (see [the relevant section](#module-the-vary-header) below)

  ## Options

  Corsica supports the following options, in the `use` macro, in
  `Corsica.Router.resource/2`, and in the `Corsica` plug.

    * `:origins` (`t:origin/0`, list of `t:origin/0`, or the string `"*"`) This option is **required**. The origin of
      a request (specified by the `"origin"` request header) will be considered a valid origin
      if it "matches" at least one of the origins specified in `:origins`. What
      "matches" means depends on the type of origin. See `t:origin/0` for more information.

      The value `"*"` can also be used to match every origin and reply with `*` as
      the value of the `access-control-allow-origin` header. If `"*"` is used, it
      must be used as the only value of `:origins` (that is, it can't be used inside
      a list of accepted origins). For example:

          # Matches everything.
          plug Corsica, origins: "*"

          # Matches one of the given origins
          plug Corsica, origins: ["http://foo.com", "http://bar.com"]

          # Matches the given regex
          plug Corsica, origins: ~r{^https?://(.*\.?)foo\.com$}

      > #### The Origin Showed to Clients {: .info}
      >
      > This option directly influences the value of the
      > `access-control-allow-origin` response header. When `:origins` is `"*"`, the
      > `access-control-allow-origin` header is set to `*` as well. If the request's
      > origin is allowed and `:origins` is something different than `"*"`, then you
      > won't see that value as the value of the `access-control-allow-origin` header:
      > the value of this header will be the request's origin (which is *mirrored*).
      > This behaviour is intentional: it's compliant with the W3C CORS specification
      > and at the same time it provides the advantage of "hiding" all the allowed
      > origins from the client (which only sees its origin as an allowed origin).

    * `:allow_methods` (list of `t:String.t/0`, or `:all`) -
      This is the list
      of methods allowed in the `access-control-request-method` header of preflight
      requests. If the method requested by the preflight request is in this list or is
      a *simple method* (`HEAD`, `GET`, or `POST`), then that method is always allowed.
      The methods specified by this option are returned in the `access-control-allow-methods`
      response header. If the value of this option is `:all`, all
      request methods are allowed and only the method in `access-control-request-method` is
      returned as the value of the `access-control-allow-methods` header. Defaults to `["PUT", "PATCH", "DELETE"]` (which means these methods
      are allowed *alongside simple methods*).

    * `:allow_headers` (list of `t:String.t/0`, or `:all`) - This is the list
      of headers allowed in the `access-control-request-headers` header of preflight
      requests. If a header requested by the preflight request is in this list or is a
      *simple header*, then that
      header is always allowed. These are the simple headers defined in the spec:
        * `Accept`
        * `Accept-Language`
        * `Content-Language`

      The headers specified by this option are returned in the
      `access-control-allow-headers` response header. If the value of this option is `:all`, all request
      headers are allowed and only the headers in `access-control-request-headers` are
      returned as the value of the `access-control-allow-headers` header. Defaults to `[]` (which means only
      the simple headers are allowed)

    * `:allow_credentials` (`t:boolean/0`) - If `true`, sends the
      `access-control-allow-credentials` with value `true`. If `false`, prevents
      that header from being sent at all. Defaults to `false`.

      > #### `Access-Control-Allow-Origin` Header with Credentials {: .info}
      >
      > If `:origins` is set to `"*"` and
      > `:allow_credentials` is set to `true`, then the value of the
      > `access-control-allow-origin` header will always be the value of the
      > `origin` request header (as per the W3C CORS specification) and not `*`.

    * `:allow_private_network` (`t:boolean/0`0 - If `true`, sets the value of the
      `access-control-allow-private-network` header used with preflight requests, which
      indicates that a resource can be safely shared with external networks. If `false`,
      the `access-control-allow-private-network` is not sent at all. Defaults to `false`.

    * `:expose_headers` (list of `t:String.t/0`) Sets the value of
      the `access-control-expose-headers` response header. This option *does
      not* have a default value; if it's not provided, the
      `access-control-expose-headers` header is not sent at all.

    * `:max_age` (`t:String.t/0` or `t:non_neg_integer/0`) Sets the value of the
      `access-control-max-age` header used with preflight requests. This option
      *does not* have a default value; if it's not provided, the
      `access-control-max-age` header is not sent at all.

    * `:telemetry_metadata` (`t:map/0`) - *extra* telemetry metadata to be included in all emitted
      events. This can be useful for identifying which `plug Corsica` call is emitting
      the events. See `Corsica.Telemetry` for more information on Telemetry in Corsica.
      Available since v2.0.0.

    * `:passthrough_non_cors_requests` (`t:boolean/0`) - If `true`, allows
      non-CORS requests to pass through the plug. See `cors_req?/1` and
      `preflight_req?/1` to understand what constitutes a CORS request. What we
      mean by "allowing non-CORS requests" means that Corsica won't verify the
      `Origin` header and such, but will still add CORS headers to the response.
      Defaults to `false`. Available since v2.1.0.

  To recap which headers are sent based on options, here's a handy table:

  | Header                                 | Request Type      | Presence in the Response       |
  |----------------------------------------|-------------------|--------------------------------|
  | `access-control-allow-origin`          | simple, preflight | always                         |
  | `access-control-allow-headers`         | preflight         | always                         |
  | `access-control-allow-credentials`     | preflight         | `allow_credentials: true`      |
  | `access-control-allow-private-network` | preflight         | `allow_private_network: true`  |
  | `access-control-expose-headers`        | preflight         | `:expose_headers` is not empty |
  | `access-control-max-age`               | preflight         | `:max_age` is present          |

  ## Usage

  You can use Corsica as a plug or as a router.

  ### Using Corsica as a Plug

  When `Corsica` is used as a plug, it intercepts **all requests**. It only sets a
  bunch of CORS headers for regular CORS requests, but it responds (with a `200 OK`
  and the appropriate headers) to preflight requests.

  If you want to use `Corsica` as a plug, be sure to plug it in your plug
  pipeline **before** any router-like plug: routers like `Plug.Router` (or
  `Phoenix.Router`) respond to HTTP verbs as well as request URLs, so if
  `Corsica` is plugged after a router then preflight requests (which are
  `OPTIONS` requests), that will often result in 404 errors since no route responds to
  them. Router-like plugs also include plugs like `Plug.Static`, which
  respond to requests and halt the pipeline.

      defmodule MyApp.Endpoint do
        plug Head
        plug Corsica, max_age: 600, origins: "*", expose_headers: ~w(X-Foo)
        plug Plug.Static
        plug MyApp.Router
      end

  ### Using Corsica as a Router Generator

  When `Corsica` is used as a plug, it doesn't provide control over which urls
  are CORS-enabled or with which options. In order to do that, you can use
  `Corsica.Router`. See the documentation for `Corsica.Router` for more
  information.

  ## The `vary` Header

  When Corsica is configured such that the `access-control-allow-origin` response
  header will vary depending on the `origin` request header, then a `vary: origin`
  response header will be set.

  ## Responding to Preflight Requests

  When the request is a preflight request and a valid one (valid origin, valid
  request method, and valid request headers), Corsica directly sends a response
  to that request instead of just adding headers to the connection (so that a
  possible plug pipeline can continue). To do this, Corsica **halts the
  connection** (through `Plug.Conn.halt/1`) and **sends a response**.

  ## Validity of CORS Requests

  "Invalid CORS request" can mean that a request doesn't have an `Origin` header
  (so it's not a CORS request at all) or that it's a CORS request but:

    * the `Origin` request header doesn't match any of the allowed origins
    * the request is a preflight request but it requests to use a method or
      some headers that are not allowed (via the `Access-Control-Request-Method`
      and `Access-Control-Request-Headers` headers)

  ## Telemetry

  Corsica emits some [telemetry](https://github.com/beam-telemetry/telemetry) events.
  See `Corsica.Telemetry` for documentation.

  ## Logging

  Corsica used to support `Logger` logging through the `:log` option. This option
  has been removed in v2.0.0 in favor of Telemetry events. If you want to keep the
  logging behavior, see `Corsica.Telemetry.attach_default_handler/1`.
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

  @behaviour Plug

  defmodule Options do
    @moduledoc false

    defstruct [
      :max_age,
      :expose_headers,
      :origins,
      allow_methods: ~w(PUT PATCH DELETE),
      allow_headers: [],
      allow_credentials: false,
      allow_private_network: false,
      passthrough_non_cors_requests: false,
      telemetry_metadata: %{}
    ]
  end

  @typedoc """
  An origin that can be specified in the `:origins` option.

  This is how each type of origin is used in order to check for "matching" origins:

    * strings - the actual origin and the allowed origin have to be identical

    * regexes - the actual origin has to match the allowed regex (as per `Regex.match?/2`)

    * `{module, function, args}` tuples - `module.function` is called with
      two extra arguments prepended to the given `args`: the current connection
      and the actual origin; if it returns `true` the origin is accepted,
      if it returns `false` the origin is not accepted.

  """
  @typedoc since: "2.0.0"
  @type origin() :: String.t() | Regex.t() | {module(), function :: atom(), args :: [term()]}

  @typedoc """
  Options accepted by most functions as well as the `Corsica` plug.

  The `%Options{}` struct is internal to Corsica and is used for performance.
  """
  @typedoc since: "2.1.0"
  @type options() :: keyword() | %Options{}

  @simple_methods ~w(GET HEAD POST)
  @simple_headers ~w(accept accept-language content-language)

  # Plug callbacks.

  @impl Plug
  def init(opts) do
    sanitize_opts(opts)
  end

  @impl Plug
  def call(%Conn{} = conn, %Options{} = opts) do
    cond do
      opts.passthrough_non_cors_requests and conn.method == "OPTIONS" ->
        send_preflight_resp(conn, opts)

      opts.passthrough_non_cors_requests ->
        put_cors_simple_resp_headers(conn, opts)

      not cors_req?(conn) ->
        conn

      not preflight_req?(conn) ->
        put_cors_simple_resp_headers(conn, opts)

      true ->
        send_preflight_resp(conn, opts)
    end
  end

  # Public so that it can be called from `Corsica.Router` (and for testing too).
  @doc false
  def sanitize_opts(opts) when is_list(opts) do
    opts
    |> require_origins_option()
    |> to_options_struct()
    |> Map.update!(:allow_methods, fn
      :all -> :all
      methods -> Enum.map(methods, &String.upcase/1)
    end)
    |> Map.update!(:allow_headers, fn
      :all -> :all
      headers -> Enum.map(headers, &String.downcase/1)
    end)
    |> maybe_update_option(:max_age, &to_string/1)
    |> maybe_update_option(:expose_headers, &Enum.join(&1, ","))
    |> maybe_warn_tuple_origins()
    |> maybe_warn_passthrough_non_cors_requests_option()
  end

  defp to_options_struct(opts), do: struct(Options, opts)

  defp require_origins_option(opts) do
    if not Keyword.has_key?(opts, :origins) do
      raise ArgumentError, "the :origins option is required"
    end

    opts
  end

  defp maybe_update_option(opts, option, update_fun) do
    if value = Map.get(opts, option) do
      Map.put(opts, option, update_fun.(value))
    else
      opts
    end
  end

  defp maybe_warn_tuple_origins(%{origins: origins} = opts) do
    for {_module, _function} = origin <- List.wrap(origins) do
      IO.warn(
        "passing #{inspect(origin)} as an allowed origin is deprecated, " <>
          "please see {module, function, args} for an alternative"
      )
    end

    opts
  end

  defp maybe_warn_passthrough_non_cors_requests_option(opts) do
    if opts.passthrough_non_cors_requests and opts.origins != "*" do
      IO.warn(
        "if the :passthrough_non_cors_requests option is set to true, " <>
          "then you need to set the :origins option to \"*\""
      )
    end

    opts
  end

  # Utilities

  @doc """
  Checks whether a given connection holds a CORS request.

  This function doesn't check if the CORS request is a *valid* CORS request: it
  just checks that it's a CORS request, that is, it has an `Origin` request
  header.
  """
  @spec cors_req?(Conn.t()) :: boolean
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
  @spec preflight_req?(Conn.t()) :: boolean
  def preflight_req?(%Conn{method: "OPTIONS"} = conn),
    do: cors_req?(conn) and get_req_header(conn, "access-control-request-method") != []

  def preflight_req?(%Conn{}), do: false

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
  (described in the documentation for the `Corsica` module).

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
  @spec send_preflight_resp(Conn.t(), 100..599, binary(), options()) :: Conn.t()
  def send_preflight_resp(conn, status \\ 200, body \\ "", opts)

  def send_preflight_resp(%Conn{} = conn, status, body, opts) when is_list(opts) do
    send_preflight_resp(conn, status, body, sanitize_opts(opts))
  end

  def send_preflight_resp(%Conn{} = conn, status, body, %Options{} = opts) do
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
  (described in the documentation for the `Corsica` module).

  ## Examples

      conn
      |> put_cors_simple_resp_headers(origins: "*", allow_credentials: true)
      |> send_resp(200, "Hello!")

  """
  @spec put_cors_simple_resp_headers(Conn.t(), options()) :: Conn.t()
  def put_cors_simple_resp_headers(conn, opts)

  def put_cors_simple_resp_headers(%Conn{} = conn, opts) when is_list(opts) do
    put_cors_simple_resp_headers(conn, sanitize_opts(opts))
  end

  def put_cors_simple_resp_headers(%Conn{} = conn, %Options{} = opts) do
    cond do
      opts.passthrough_non_cors_requests ->
        execute_telemetry(conn, opts, [:accepted_request], %{request_type: :simple})

        conn
        |> put_common_headers(opts)
        |> put_expose_headers_header(opts)

      not cors_req?(conn) ->
        execute_telemetry(conn, opts, [:invalid_request], %{request_type: :simple})
        conn

      not allowed_origin?(conn, opts) ->
        execute_telemetry(conn, opts, [:rejected_request], %{request_type: :simple})
        conn

      true ->
        execute_telemetry(conn, opts, [:accepted_request], %{request_type: :simple})

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
    * `Access-Control-Allow-Private-Network` (if the `:allow_private_network` option is
      `true`)
    * `Access-Control-Max-Age` (if the `:max_age` option is present)

  ## Options

  This function accepts the same options accepted by the `Corsica` plug
  (described in the documentation for the `Corsica` module).

  ## Examples

      put_cors_preflight_resp_headers conn, [
        max_age: 86400,
        allow_headers: ~w(X-Header),
        allow_private_network: true,
        origins: ~r/\w+\.foo\.com$/
      ]

  """
  @spec put_cors_preflight_resp_headers(Conn.t(), options()) :: Conn.t()
  def put_cors_preflight_resp_headers(conn, opts)

  def put_cors_preflight_resp_headers(%Conn{} = conn, opts) when is_list(opts) do
    put_cors_preflight_resp_headers(conn, sanitize_opts(opts))
  end

  def put_cors_preflight_resp_headers(%Conn{} = conn, %Options{} = opts) do
    cond do
      opts.passthrough_non_cors_requests ->
        execute_telemetry(conn, opts, [:accepted_request], %{request_type: :preflight})
        put_cors_preflight_resp_headers_no_check(conn, opts)

      not preflight_req?(conn) ->
        execute_telemetry(conn, opts, [:invalid_request], %{request_type: :preflight})
        conn

      not allowed_origin?(conn, opts) ->
        execute_telemetry(conn, opts, [:rejected_request], %{
          request_type: :preflight,
          reason: :origin_not_allowed
        })

        conn

      not allowed_preflight?(conn, opts) ->
        # More detailed info is emitted from allowed_preflight?/2.
        conn

      true ->
        execute_telemetry(conn, opts, [:accepted_request], %{request_type: :preflight})
        put_cors_preflight_resp_headers_no_check(conn, opts)
    end
  end

  defp put_cors_preflight_resp_headers_no_check(conn, opts) do
    conn
    |> put_common_headers(opts)
    |> put_allow_methods_header(opts)
    |> put_allow_headers_header(opts)
    |> put_allow_private_network_header(opts)
    |> put_max_age_header(opts)
  end

  defp put_common_headers(conn, %Options{} = opts) do
    conn
    |> put_allow_credentials_header(opts)
    |> put_allow_origin_header(opts)
    |> update_vary_header(opts)
  end

  defp put_allow_credentials_header(conn, %Options{allow_credentials: allow_credentials}) do
    if allow_credentials do
      put_resp_header(conn, "access-control-allow-credentials", "true")
    else
      conn
    end
  end

  defp put_allow_origin_header(conn, %Options{passthrough_non_cors_requests: true, origins: "*"}) do
    put_resp_header(conn, "access-control-allow-origin", "*")
  end

  defp put_allow_origin_header(conn, %Options{} = opts) do
    [actual_origin | _] = get_req_header(conn, "origin")

    value =
      if send_wildcard_origin?(opts) do
        "*"
      else
        actual_origin
      end

    put_resp_header(conn, "access-control-allow-origin", value)
  end

  # Add `vary: origin` response header if the `access-control-allow-origin` response header will
  # vary depending on the `origin` request header.
  defp update_vary_header(conn, %Options{origins: [origin]} = opts) do
    update_vary_header(conn, %{opts | origins: origin})
  end

  defp update_vary_header(conn, %Options{origins: origins} = opts) do
    cond do
      is_binary(origins) and origins != "*" -> conn
      send_wildcard_origin?(opts) -> conn
      true -> %{conn | resp_headers: [{"vary", "origin"} | conn.resp_headers]}
    end
  end

  defp send_wildcard_origin?(%Options{origins: origins, allow_credentials: allow_credentials}) do
    # '*' cannot be used as the value of the `Access-Control-Allow-Origins`
    # header if `Access-Control-Allow-Credentials` is true.
    origins == "*" and not allow_credentials
  end

  defp put_allow_methods_header(conn, %Options{allow_methods: allow_methods}) do
    value =
      if allow_methods == :all do
        hd(get_req_header(conn, "access-control-request-method"))
      else
        Enum.join(allow_methods, ",")
      end

    put_resp_header(conn, "access-control-allow-methods", value)
  end

  defp put_allow_headers_header(conn, %Options{allow_headers: allow_headers}) do
    allowed_headers =
      if allow_headers == :all do
        for req_headers <- get_req_header(conn, "access-control-request-headers"),
            req_headers = String.downcase(req_headers),
            req_header <- Plug.Conn.Utils.list(req_headers),
            do: req_header
      else
        allow_headers
      end

    put_resp_header(conn, "access-control-allow-headers", Enum.join(allowed_headers, ","))
  end

  defp put_allow_private_network_header(conn, %Options{allow_private_network: allow?}) do
    if allow? do
      put_resp_header(conn, "access-control-allow-private-network", "true")
    else
      conn
    end
  end

  defp put_max_age_header(conn, %Options{max_age: max_age}) do
    if max_age do
      put_resp_header(conn, "access-control-max-age", max_age)
    else
      conn
    end
  end

  defp put_expose_headers_header(conn, %Options{expose_headers: expose_headers}) do
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
  def allowed_origin?(_conn, %Options{origins: "*"}) do
    true
  end

  def allowed_origin?(conn, %Options{origins: origins}) do
    [origin | _] = get_req_header(conn, "origin")
    Enum.any?(List.wrap(origins), &matching_origin?(&1, origin, conn))
  end

  defp matching_origin?(origin, origin, _conn), do: true
  defp matching_origin?(allowed, _actual, _conn) when is_binary(allowed), do: false
  defp matching_origin?(%Regex{} = allowed, actual, _conn), do: Regex.match?(allowed, actual)

  defp matching_origin?({module, function, args}, actual, conn)
       when is_atom(module) and is_atom(function) and is_list(args) do
    apply(module, function, [conn, actual | args])
  end

  defp matching_origin?({module, function}, actual, _conn)
       when is_atom(module) and is_atom(function) do
    apply(module, function, [actual])
  end

  # Made public for testing.
  @doc false
  def allowed_preflight?(conn, %Options{} = opts) do
    allowed_request_method?(conn, opts) and allowed_request_headers?(conn, opts)
  end

  defp allowed_request_method?(_conn, %Options{allow_methods: :all}) do
    true
  end

  defp allowed_request_method?(conn, %Options{allow_methods: allow_methods} = opts) do
    # We can safely assume there's an Access-Control-Request-Method header
    # otherwise the request wouldn't have been identified as a preflight
    # request.
    [req_method | _] = get_req_header(conn, "access-control-request-method")

    if req_method in @simple_methods or req_method in allow_methods do
      true
    else
      execute_telemetry(conn, opts, [:rejected_request], %{
        request_type: :preflight,
        reason: {:req_method_not_allowed, req_method}
      })

      false
    end
  end

  defp allowed_request_headers?(_conn, %Options{allow_headers: :all}) do
    true
  end

  defp allowed_request_headers?(conn, %Options{allow_headers: allow_headers} = opts) do
    non_allowed_headers =
      for req_headers <- get_req_header(conn, "access-control-request-headers"),
          req_headers = String.downcase(req_headers),
          req_header <- Plug.Conn.Utils.list(req_headers),
          not (req_header in @simple_headers or req_header in allow_headers),
          do: req_header

    if non_allowed_headers == [] do
      true
    else
      execute_telemetry(conn, opts, [:rejected_request], %{
        request_type: :preflight,
        reason: {:req_headers_not_allowed, non_allowed_headers}
      })

      false
    end
  end

  defp execute_telemetry(conn, %Options{} = opts, event_name, extra_meta) do
    meta =
      %{conn: conn}
      |> Map.merge(extra_meta)
      |> Map.merge(opts.telemetry_metadata)

    :telemetry.execute([:corsica] ++ event_name, _measurements = %{}, meta)
  end
end
