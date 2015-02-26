defmodule Corsica.Preflight do
  @moduledoc false

  import Plug.Conn
  import Corsica, only: [put_common_headers: 2]

  def handle_req(conn, opts) do
    if valid_cors_request?(conn, opts) do
      send_preflight(conn, opts)
    else
      conn
    end
  end

  defp valid_cors_request?(conn, opts) do
    allowed_request_method?(conn, opts[:allow_methods]) and
      allowed_request_headers?(conn, opts[:allow_headers])
  end

  defp allowed_request_method?(conn, allowed_methods) do
    # We can safely assume there's an Access-Control-Request-Method header
    # otherwise the request wouldn't have been identified as a preflight request.
    req_method = conn |> get_req_header("access-control-request-method") |> hd
    req_method in allowed_methods
  end

  defp allowed_request_headers?(conn, allowed_headers) do
    # If there is no Access-Control-Request-Headers header, this will all amount
    # to an empty list for which `Enum.all?/2` will return `true`.
    conn
    |> get_req_header("access-control-request-headers")
    |> Enum.flat_map(&Plug.Conn.Utils.list/1)
    |> Enum.map(&String.downcase/1)
    |> Enum.all?(&(&1 in allowed_headers))
  end

  defp send_preflight(conn, opts) do
    conn
    |> put_allow_methods_header(opts)
    |> put_allow_headers_header(opts)
    |> put_max_age_header(opts)
    |> put_common_headers(opts)
    |> halt
    |> send_resp(200, "")
  end

  defp put_allow_methods_header(conn, opts) do
    value = opts |> Keyword.fetch!(:allow_methods) |> Enum.join(", ")
    put_resp_header(conn, "access-control-allow-methods", value)
  end

  defp put_allow_headers_header(conn, opts) do
    value = opts |> Keyword.fetch!(:allow_headers) |> Enum.join(", ")
    put_resp_header(conn, "access-control-allow-headers", value)
  end

  defp put_max_age_header(conn, opts) do
    if max_age = opts[:max_age] do
      put_resp_header(conn, "access-control-max-age", max_age)
    else
      conn
    end
  end
end
