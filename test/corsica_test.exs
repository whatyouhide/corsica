defmodule CorsicaTest do
  use ExUnit.Case, async: true
  use Plug.Test

  defmodule Matching do
    use Corsica, origins: "*"
    resources ["/foo", "/bar"], expose_headers: ~w(foobar)
    resources ["/wildcard/*"], expose_headers: ~w(wildcard)
  end

  defmodule Options do
    use Corsica, origins: "*"
    resources ["/all"]
    resources ["/only-some-origins"], origins: ["a.b", "b.a"]
    resources ["/only-one-origin"], origins: ["a.b"]
    resources ["/regex"], origins: ~r/(foo|bar)\.com$/

    resources ["/allow_origin"],
      origins: ["foo.bar"],
      allow_origin: "custom-origin.com"
  end

  defmodule Preflight do
    use Corsica, origins: "*",
                 allow_methods: ~w(PUT PATCH),
                 allow_headers: ~w(X-Header X-Other-Header),
                 max_age: 300

    resources ["/*"]
  end

  defmodule Credentials do
    use Corsica, origins: "*"
    resources ["/allow-credentials"], allow_credentials: true
    resources ["/dont-allow-credentials"], allow_credentials: false
  end

  defmodule AsPlug do
    use Plug.Builder
    plug Corsica, origins: ["foo.com"], resources: ["/wildcard/*", "/foo"]
    plug :match

    def match(conn, _opts) do
      send_resp(conn, 200, "match")
    end
  end

  test "cors_request?/1" do
    import Corsica, only: [cors_request?: 1]

    conn = ac_conn(:get, "/")
    refute cors_request?(conn)
    conn = ac_conn(:get, "/") |> put_origin("foo")
    assert cors_request?(conn)
  end

  test "preflight_request?/1" do
    import Corsica, only: [preflight_request?: 1]
    headers = [{"origin", "http://foo.bar.com"}]

    conn = ac_conn(:get, "/", headers)
    refute preflight_request?(conn)
    conn = ac_conn(:post, "/", headers)
    refute preflight_request?(conn)
    conn = ac_conn(:head, "/", headers)
    refute preflight_request?(conn)
    conn = ac_conn(:options, "/", headers)
    refute preflight_request?(conn)
    conn = ac_conn(:options, "/", [{"access-control-request-method", "GET"}|headers])
    assert preflight_request?(conn)
  end

  test "matches correctly" do
    conn = ac_conn(:get, "/foo", [{"origin", "foo.com"}]) |> c(Matching)
    assert resp_header(conn, "access-control-allow-origin") == "*"
    assert resp_header(conn, "access-control-expose-headers") == "foobar"

    conn = ac_conn(:get, "/wildcard/foobar", [{"origin", "bar.com"}]) |> c(Matching)
    assert resp_header(conn, "access-control-allow-origin") == "*"
    assert resp_header(conn, "access-control-expose-headers") == "wildcard"

    # When a request doesn't match, no CORS headers are returned.
    conn = ac_conn(:get, "/no-match", [{"origin", "baz.com"}]) |> c(Matching)
    refute resp_header(conn, "access-control-allow-origin")
    refute resp_header(conn, "access-control-expose-headers")
  end

  test "options can be passed to `use/2` and then overridden" do
    conn = ac_conn(:get, "/all") |> put_origin("foo.bar") |> Options.call([])
    assert resp_header(conn, "access-control-allow-origin") == "*"

    conn = ac_conn(:get, "/only-some-origins") |> put_origin("b.a") |> Options.call([])
    assert resp_header(conn, "access-control-allow-origin") == "b.a"

    conn = ac_conn(:get, "/only-some-origins") |> put_origin("not.allowed") |> c(Options)
    refute resp_header(conn, "access-control-allow-origin")
  end

  test "simple request: valid origin" do
    conn = ac_conn(:get, "/only-some-origins", [{"origin", "a.b"}]) |> c(Options)
    assert resp_header(conn, "access-control-allow-origin") == "a.b"
  end

  test "simple request: invalid origin" do
    conn = ac_conn(:get, "/only-some-origins", [{"origin", "not.valid"}]) |> c(Options)
    refute resp_header(conn, "access-control-allow-origin")
  end

  test "preflight requests: valid method" do
    conn = ac_conn(:options, "/foo")
           |> put_origin("a.b")
           |> put_req_header("access-control-request-method", "PUT")
           |> c(Preflight)

    assert conn.status == 200
    assert conn.resp_body == ""
    assert resp_header(conn, "access-control-allow-methods") == "PUT, PATCH"
    assert resp_header(conn, "access-control-allow-headers") == "x-header, x-other-header"
    assert resp_header(conn, "access-control-allow-origin") == "*"
    assert resp_header(conn, "access-control-max-age") == "300"
  end

  test "preflight requests: invalid method" do
    conn = ac_conn(:options, "/foo")
           |> put_origin("a.b")
           |> put_req_header("access-control-request-method", "OPTIONS")
           |> c(Preflight)

    refute conn.status
    refute conn.resp_body
    refute resp_header(conn, "access-control-allow-methods")
    refute resp_header(conn, "access-control-allow-headers")
    refute resp_header(conn, "access-control-allow-origin")
    refute resp_header(conn, "access-control-max-age")
  end

  test "preflight requests: valid headers" do
    headers = [{"origin", "a.b"},
               {"access-control-request-method", "PATCH"},
               {"access-control-request-headers", "X-Other-Header, X-Header"}]
    conn = ac_conn(:options, "/foo", headers) |> c(Preflight)

    assert conn.status == 200
    assert conn.resp_body == ""
    assert resp_header(conn, "access-control-allow-methods") == "PUT, PATCH"
    assert resp_header(conn, "access-control-allow-headers") == "x-header, x-other-header"
    assert resp_header(conn, "access-control-allow-origin") == "*"
    assert resp_header(conn, "access-control-max-age") == "300"
  end

  test "preflight requests: invalid headers" do
    headers = [{"origin", "a.b"},
               {"access-control-request-method", "PATCH"},
               {"access-control-request-headers", "X-Evil-Header, X-Header"}]
    conn = ac_conn(:options, "/foo", headers) |> c(Preflight)

    refute conn.status
    refute conn.resp_body
    refute resp_header(conn, "access-control-allow-methods")
    refute resp_header(conn, "access-control-allow-headers")
    refute resp_header(conn, "access-control-allow-origin")
    refute resp_header(conn, "access-control-max-age")
  end

  test "regex origins" do
    conn = ac_conn(:get, "/regex") |> put_origin("http://foo.com") |> c(Options)
    assert resp_header(conn, "access-control-allow-origin") == "http://foo.com"

    conn = ac_conn(:get, "/regex") |> put_origin("http://baz.com") |> c(Options)
    refute resp_header(conn, "access-contorl-allow-origin")
  end

  test "Vary header" do
    conn = ac_conn(:get, "/only-some-origins") |> put_origin("a.b") |> c(Options)
    assert resp_header(conn, "vary") == "origin"

    conn = ac_conn(:get, "/only-some-origins")
            |> put_origin("a.b")
            |> put_resp_header("vary", "host")
            |> c(Options)
    assert "origin" in resp_header(conn, "vary")

    conn = ac_conn(:get, "/only-one-origin") |> put_origin("a.b") |> c(Options)
    refute resp_header(conn, "vary")
  end

  test "credentials" do
    conn = ac_conn(:get, "/allow-credentials") |> put_origin("http://foo.com") |> c(Credentials)
    assert resp_header(conn, "access-control-allow-origin") == "http://foo.com"
    assert resp_header(conn, "access-control-allow-credentials") == "true"

    conn = ac_conn(:get, "/dont-allow-credentials") |> put_origin("http://bar.com") |> c(Credentials)
    assert resp_header(conn, "access-control-allow-origin") == "*"
    refute resp_header(conn, "access-control-allow-credentials")
  end

  test "as a plug" do
    conn = ac_conn(:get, "/foo") |> put_origin("foo.com") |> c(AsPlug)
    assert conn.status == 200
    assert conn.resp_body == "match"
    assert resp_header(conn, "access-control-allow-origin") == "foo.com"

    conn = ac_conn(:get, "/wildcard/anything") |> put_origin("foo.com") |> c(AsPlug)
    assert conn.status == 200
    assert conn.resp_body == "match"
    assert resp_header(conn, "access-control-allow-origin") == "foo.com"

    conn = ac_conn(:get, "/bar", [{"origin", "foo.com"}]) |> c(AsPlug)
    assert conn.status == 200
    assert conn.resp_body == "match"
    refute resp_header(conn, "access-control-allow-origin")
  end

  # Helpers.

  defp c(conn, plug),
    do: plug.call(conn, [])

  defp ac_conn(method, path, headers \\ []),
    do: conn(method, path, "", headers: [{"content-type", "text/plain"}|headers])

  defp put_origin(conn, origin),
    do: put_req_header(conn, "origin", origin)

  defp resp_header(conn, header) do
    case get_resp_header(conn, header) do
      []       -> nil
      [header] -> header
      headers  -> headers
    end
  end
end
