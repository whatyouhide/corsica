defmodule Corsica.RouterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  defmodule MyRouter do
    use Corsica.Router

    @opts [origins: "*", max_age: 600]

    resource "/foo", @opts
    resource "/bar", Keyword.merge(@opts, origins: ~r/\.com$/)
    resource "/wild/*", @opts
    resource "/preflight", Keyword.merge(@opts, allow_methods: ~w(PUT))
  end

  defmodule Pipeline do
    use Plug.Router
    plug MyRouter
    plug :match
    plug :dispatch

    get _, do: send_resp(conn, 200, "match")
  end

  test "/foo" do
    conn = conn(:get, "/foo") |> put_origin("foo.com") |> Pipeline.call([])
    assert conn.resp_body == "match"
    assert get_resp_header(conn, "access-control-allow-origin") == ["*"]
  end

  test "/bar" do
    conn = conn(:get, "/bar") |> put_origin("foo.com") |> Pipeline.call([])
    assert conn.resp_body == "match"
    assert get_resp_header(conn, "access-control-allow-origin") == ["foo.com"]

    conn = conn(:get, "/bar") |> put_origin("foo.org") |> Pipeline.call([])
    assert conn.resp_body == "match"
    assert get_resp_header(conn, "access-control-allow-origin") == []
  end

  test "/wild" do
    conn = conn(:get, "/wild/ca/rd") |> put_origin("foo.com") |> Pipeline.call([])
    assert conn.resp_body == "match"
    assert get_resp_header(conn, "access-control-allow-origin") == ["*"]
  end

  test "preflight requests" do
    conn = conn(:options, "/preflight")
            |> put_origin("foo.com")
            |> put_req_header("access-control-request-method", "PUT")
            |> Pipeline.call([])
    assert conn.state == :sent
    assert conn.resp_body == ""
    assert get_resp_header(conn, "access-control-allow-origin") == ["*"]
    assert get_resp_header(conn, "access-control-allow-methods") == ["PUT"]
  end

  defp put_origin(conn, origin), do: put_req_header(conn, "origin", origin)
end
