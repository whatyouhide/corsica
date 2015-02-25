defmodule Corsica.Preflight do
  @moduledoc false

  import Plug.Conn

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
    conn
    |> get_req_header("access-control-request-method")
    |> hd
    |> String.upcase
    |> (fn(method) -> method in allowed_methods end).()
  end

  defp allowed_request_headers?(conn, allowed_headers) do
    case get_req_header(conn, "access-control-request-headers") do
      []     -> true
      header ->
        header
        |> Enum.flat_map(&String.split(&1, ","))
        |> Enum.map(&String.strip/1)
        |> Enum.map(&String.downcase/1)
        |> Enum.all?(&(&1 in allowed_headers))
    end
  end

  defp send_preflight(conn, opts) do
    conn
    |> put_allow_methods_header(opts)
    |> put_allow_headers_header(opts)
    |> put_max_age_header(opts)
    |> Corsica.put_common_headers(opts)
    |> halt
    |> send_resp(200, "")
  end

  defp put_allow_methods_header(conn, opts) do
    value = Keyword.fetch!(opts, :allow_methods) |> Enum.join(", ")
    put_resp_header(conn, "access-control-allow-methods", value)
  end

  defp put_allow_headers_header(conn, opts) do
    value = Keyword.fetch!(opts, :allow_headers) |> Enum.join(", ")
    put_resp_header(conn, "access-control-allow-headers", value)
  end

  defp put_max_age_header(conn, opts) do
    if max_age = opts[:max_age] do
      put_resp_header(conn, "access-control-max-age", to_string(max_age))
    else
      conn
    end
  end
end
