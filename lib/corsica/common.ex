defmodule Corsica.Common do
  @moduledoc false

  import Plug.Conn

  def put_common_headers(conn, opts) do
    conn
    |> put_allow_credentials_header(opts)
    |> put_allow_origin_header(opts)
    |> update_vary_header(opts[:origins])
  end

  defp put_allow_credentials_header(conn, opts) do
    if opts[:allow_credentials] do
      put_resp_header(conn, "access-control-allow-credentials", "true")
    else
      conn
    end
  end

  defp put_allow_origin_header(conn, opts) do
    actual_origin = Corsica.get_origin(conn)
    allowed_origins = Keyword.fetch!(opts, :origins)

    value = if allowed_origins == "*" and not opts[:allow_credentials] do
      "*"
    else
      actual_origin
    end

    put_resp_header(conn, "access-control-allow-origin", value)
  end

  # Only update the Vary header if the origin is not a binary (it could be a
  # regex or a function) or if there's a list of more than one origins.
  defp update_vary_header(conn, "*"),
    do: conn
  defp update_vary_header(conn, origin) when is_binary(origin),
    do: conn
  defp update_vary_header(conn, [origin]) when is_binary(origin),
    do: conn
  defp update_vary_header(conn, _origin),
    do: update_in(conn.resp_headers, &[{"vary", "origin"}|&1])
end
