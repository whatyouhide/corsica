defmodule CorsicaTest do
  use ExUnit.Case, async: true
  use Plug.Test

  import Corsica

  test "cors_req?/1" do
    refute conn(:get, "/") |> cors_req?
    assert conn(:get, "/")
           |> put_origin("http://example.com")
           |> cors_req?
  end

  test "preflight_req?/1" do
    refute conn(:get, "/") |> put_origin("http://example.com") |> preflight_req?
    refute conn(:head, "/") |> put_origin("http://example.com") |> preflight_req?
    refute conn(:options, "/") |> put_origin("http://example.com") |> preflight_req?

    assert conn(:options, "/")
           |> put_origin("http://example.com")
           |> put_req_header("access-control-request-method", "GET")
           |> preflight_req?

    # Non-CORS requests aren't preflight requests, for sure.
    refute conn(:get, "/") |> preflight_req?
    refute conn(:options, "/")
           |> put_req_header("access-control-request-method", "GET")
           |> preflight_req?
  end

  test "sanitize_opts/1" do
    assert sanitize_opts(max_age: 600)[:max_age] == "600"
    assert sanitize_opts([])[:max_age] == nil
    assert sanitize_opts(allow_methods: ~w(get pOSt))[:allow_methods] == ~w(GET POST)
    assert sanitize_opts(allow_headers: ~w(X-Header))[:allow_headers] == ~w(x-header)
    assert sanitize_opts(expose_headers: ~w(X-Foo X-Bar))[:expose_headers] == "X-Foo, X-Bar"
  end

  test "allowed_origin?/2: allowed origins" do
    conn = conn(:get, "/") |> put_origin("http://foo.com")
    assert allowed_origin?(conn, origins: "*")
    assert allowed_origin?(conn, origins: "http://foo.com")
    assert allowed_origin?(conn, origins: ["http://foo.com"])
    assert allowed_origin?(conn, origins: ["http://bar.com", "http://foo.com"])
    assert allowed_origin?(conn, origins: ~r/(foo|bar)\.com$/)
    assert allowed_origin?(conn, origins: &(&1 =~ "foo.com"))
  end

  test "allowed_origin?/2: non-allowed origins" do
    conn = conn(:get, "/") |> put_origin("http://foo.com")
    refute allowed_origin?(conn, origins: "foo.com")
    refute allowed_origin?(conn, origins: ["http://foo.org"])
    refute allowed_origin?(conn, origins: ["http://bar.com", "http://baz.com"])
    refute allowed_origin?(conn, origins: ~r/(foo|bar)\.org$/)
    refute allowed_origin?(conn, origins: &(&1 == String.upcase(&1)))
  end

  test "allowed_preflight?/2: allowed requests" do
    conn = conn(:get, "/")
            |> put_origin("http://foo.com")
            |> put_req_header("access-control-request-method", "PUT")
    assert allowed_preflight?(conn, allow_methods: ~w(PUT PATCH))
    assert allowed_preflight?(conn, allow_methods: ~w(put))
    assert allowed_preflight?(conn, allow_methods: ~w(PUT), allow_headers: ~w(X-Foo))

    conn = conn |> put_req_header("access-control-request-headers", "X-Foo, X-Bar")
    assert allowed_preflight?(conn, allow_methods: ~w(PUT), allow_headers: ~w(X-Bar x-foo))
  end

  test "allowed_preflight?/2: non-allowed requests" do
    conn = conn(:get, "/")
            |> put_origin("http://foo.com")
            |> put_req_header("access-control-request-method", "OPTIONS")
    refute allowed_preflight?(conn, allow_methods: ~w(PUT PATCH))
    refute allowed_preflight?(conn, allow_methods: ~w(put))
    refute allowed_preflight?(conn, allow_methods: ~w(PUT), allow_headers: ~w(X-Foo))

    conn = conn |> put_req_header("access-control-request-headers", "X-Foo, X-Bar")
    refute allowed_preflight?(conn, allow_methods: ~w(OPTIONS), allow_headers: ~w(X-Bar))
    refute allowed_preflight?(conn, allow_methods: ~w(OPTIONS), allow_headers: ~w(x-bar))
  end

  test "put_cors_simple_resp_headers/2: access-control-allow-origin" do
    conn = conn(:get, "/")
            |> put_origin("http://foo.bar")
            |> put_cors_simple_resp_headers(origins: "*")
    assert get_resp_header(conn, "access-control-allow-origin") == ["*"]
    assert get_resp_header(conn, "access-control-expose-headers") == []

    conn = conn(:get, "/") |> put_cors_simple_resp_headers(origins: "*")
    assert get_resp_header(conn, "access-control-allow-origin") == []
  end

  test "put_cors_simple_resp_headers/2: access-control-allow-credentials" do
    conn = conn(:get, "/foo")
            |> put_origin("http://foo.bar")
            |> put_cors_simple_resp_headers(allow_credentials: true)
    assert get_resp_header(conn, "access-control-allow-credentials") == ["true"]
    assert get_resp_header(conn, "access-control-allow-origin") == ["http://foo.bar"]
    assert get_resp_header(conn, "access-control-expose-headers") == []

    conn = conn(:get, "/foo")
            |> put_origin("http://foo.bar")
            |> put_cors_simple_resp_headers(allow_credentials: false)
    assert get_resp_header(conn, "access-control-allow-credentials") == []
    assert get_resp_header(conn, "access-control-allow-origin") == ["*"]
    assert get_resp_header(conn, "access-control-expose-headers") == []
  end

  test "put_cors_simple_resp_headers/2: access-control-expose-headers" do
    conn = conn(:get, "/foo")
            |> put_origin("http://foo.bar")
            |> put_cors_simple_resp_headers(expose_headers: ~w(X-Foo X-Bar))
    assert get_resp_header(conn, "access-control-allow-origin") == ["*"]
    assert get_resp_header(conn, "access-control-expose-headers") == ["X-Foo, X-Bar"]
  end

  test "put_cors_simple_resp_headers/2: 'origin' is added to the 'vary' header" do
    conn = conn(:get, "/foo") |> put_origin("http://foo.com")

    new_conn = put_cors_simple_resp_headers(conn, origins: "*")
    assert get_resp_header(new_conn, "vary") == []

    new_conn = put_cors_simple_resp_headers(conn, origins: "http://foo.com")
    assert get_resp_header(new_conn, "vary") == []

    new_conn = put_cors_simple_resp_headers(conn, origins: ["http://foo.com"])
    assert get_resp_header(new_conn, "vary") == []

    new_conn = put_cors_simple_resp_headers(conn, origins: ["http://foo.com", "http://bar.com"])
    assert get_resp_header(new_conn, "vary") == ["origin"]

    new_conn = conn
                |> put_resp_header("vary", "content-length")
                |> put_cors_simple_resp_headers(origins: ["http://foo.com", "http://bar.com"])
    assert get_resp_header(new_conn, "vary") == ["origin", "content-length"]
  end

  test "put_cors_preflight_resp_headers/2: access-control-allow-methods" do
    conn = conn(:options, "/")
            |> put_origin("http://example.com")
            |> put_req_header("access-control-request-method", "PUT")
            |> put_cors_preflight_resp_headers(allow_methods: ~w(GET PUT))

    assert get_resp_header(conn, "access-control-allow-origin") == ["*"]
    assert get_resp_header(conn, "access-control-allow-methods") == ["GET, PUT"]
    assert get_resp_header(conn, "access-control-allow-headers") == [""]
    assert get_resp_header(conn, "access-control-max-age") == []
  end

  test "put_cors_preflight_resp_headers/2: access-control-allow-headers" do
    opts = [allow_methods: ~w(PUT), allow_headers: ~w(X-Foo X-Bar)]
    conn = conn(:options, "/")
            |> put_origin("http://example.com")
            |> put_req_header("access-control-request-method", "PUT")
            |> put_cors_preflight_resp_headers(opts)

    assert get_resp_header(conn, "access-control-allow-origin") == ["*"]
    assert get_resp_header(conn, "access-control-allow-methods") == ["PUT"]
    assert get_resp_header(conn, "access-control-allow-headers") == ["x-foo, x-bar"]
    assert get_resp_header(conn, "access-control-max-age") == []
  end

  test "put_cors_preflight_resp_headers/2: access-control-max-age" do
    conn = conn(:options, "/")
            |> put_origin("http://example.com")
            |> put_req_header("access-control-request-method", "PUT")
            |> put_cors_preflight_resp_headers(max_age: 400)
    assert get_resp_header(conn, "access-control-max-age") == ["400"]
  end

  test "send_preflight_resp/4: valid preflight request" do
    conn = conn(:options, "/")
            |> put_origin("http://example.com")
            |> put_req_header("access-control-request-method", "PUT")
            |> send_preflight_resp(allow_methods: ~w(PUT))
    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body == ""
    assert get_resp_header(conn, "access-control-allow-origin") == ["*"]
    assert get_resp_header(conn, "access-control-allow-methods") == ["PUT"]
  end

  test "send_preflight_resp/4: invalid preflight request" do
    conn = conn(:options, "/")
            |> put_origin("http://example.com")
            |> put_req_header("access-control-request-method", "PUT")
            |> send_preflight_resp(400, allow_methods: ~w(GET POST))
    assert conn.state == :sent
    assert conn.status == 400
    assert conn.resp_body == ""
    assert get_resp_header(conn, "access-control-allow-origin") == []
    assert get_resp_header(conn, "access-control-allow-methods") == []
  end

  defp put_origin(conn, origin), do: put_req_header(conn, "origin", origin)
end
