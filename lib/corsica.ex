defmodule Corsica do
  @moduledoc """
  Plug and DSL for handling CORS requests.
  """

  import Plug.Conn
  alias Plug.Conn
  alias Corsica.Preflight
  alias Corsica.Actual
  alias Corsica.Helpers

  @default_opts [
    expose_headers: ~w(),
    max_age: 1728000,
    allow_headers: ~w(),
    allow_methods: ~w(),
    allow_credentials: false,
  ]

  @doc false
  defmacro __using__(opts) do
    quote do
      opts = Corsica.sanitize_opts(unquote(opts))
      use Corsica.DSL, opts
    end
  end

  @behaviour Plug

  def init(opts), do: sanitize_opts(opts)

  def call(%Plug.Conn{path_info: path_info} = conn, opts) do
    {routes, opts} = Keyword.pop(opts, :resources, [])
    if cors_request?(conn) and matching_route?(path_info, routes) do
      handle_req(conn, opts)
    else
      conn
    end
  end

  defp matching_route?(path_info, routes) do
    routes = Enum.map(routes, &Helpers.compile_route/1)
    Enum.any?(routes, &match?(^&1, path_info))
  end

  @doc """
  """
  def cors_request?(conn),
    do: Plug.Conn.get_req_header(conn, "origin") != []

  def sanitize_opts(opts) do
    import String, only: [upcase: 1, downcase: 1]
    import Enum, only: [map: 2]

    Keyword.merge(@default_opts, opts)
    |> Keyword.update!(:allow_methods, fn(m) -> map(m, &upcase/1) end)
    |> Keyword.update!(:allow_headers, fn(h) -> map(h, &downcase/1) end)
  end


  # Request handlers.

  @doc """
  """
  @spec handle_req(Plug.Conn.t, [Keyword.t]) :: Plug.Conn.t
  def handle_req(conn, opts) do
    if preflight_request?(conn) do
      Preflight.handle_req(conn, opts)
    else
      Actual.handle_req(conn, opts)
    end
  end

  # Made public for testing.
  @doc false
  def preflight_request?(%Conn{method: "OPTIONS"} = conn),
    do: get_req_header(conn, "access-control-request-method") != []
  def preflight_request?(%Conn{}),
    do: false


  @doc false
  def put_common_headers(conn, opts) do
    conn
    |> put_allow_origin_header(opts)
    |> put_allow_credentials_header(opts)
  end

  defp put_allow_origin_header(conn, opts) do
    allowed_origins = Keyword.fetch!(opts, :origins)
    origin          = conn |> get_req_header("origin") |> hd

    header = allow_origin_header(allowed_origins, origin, opts[:allow_origin])
    put_resp_header(conn, "access-control-allow-origin", header)
  end

  defp allow_origin_header("*", _origin, _custom), do: "*"
  defp allow_origin_header(allowed_origins, origin, custom) do
    if Enum.find(List.wrap(allowed_origins), &matching_origin?(&1, origin)) do
      origin
    else
      custom || hd(allowed_origins)
    end
  end

  defp matching_origin?(origin, origin),
    do: true
  defp matching_origin?(allowed, _origin) when is_binary(allowed),
    do: false
  defp matching_origin?(allowed, origin),
    do: Regex.match?(allowed, origin)

  defp put_allow_credentials_header(conn, opts) do
    if opts[:allow_credentials] do
      put_resp_header(conn, "access-control-allow-credentials", "true")
    else
      conn
    end
  end
end
