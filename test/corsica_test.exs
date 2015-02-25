defmodule CorsicaTest do
  use ExUnit.Case, async: true
  use Plug.Test

  defmodule Matching do
    use Corsica, origins: "*"
    resources ["/foo", "/bar"], allow_credentials: false
    resources ["/wildcard/*"], allow_credentials: true
  end

  defmodule Options do
    use Corsica, origins: "*"
    resources ["/all"]
    resources ["/only-some-origins"], origins: ["a.b", "b.a"]
    resources ["/regex"], origins: ~r/(foo|bar)\.com$/, allow_origin: "foo.com"
    resources ["/allow_origin"],
      origins: ["foo.bar"],
      allow_origin: "custom-origin.com"

    resources ["/credentials"], allow_credentials: true
  end

  defmodule Preflight do
    use Corsica, origins: "*",
                 allow_methods: ~w(PUT PATCH),
                 allow_headers: ~w(X-Header X-Other-Header),
                 max_age: 300

    resources :all
  end

  defmodule AsPlug do
    use Plug.Builder
    plug Corsica,
      origins: ["foo.com"],
      resources: ["/wildcard/*", "/foo"]
    plug :match

    def match(conn, _opts) do
      send_resp(conn, 200, "match")
    end
  end

  test "cors_request?/1" do
    import Corsica, only: [cors_request?: 1]

    conn = ac_conn(:get, "/", [])
    refute cors_request?(conn)

    conn = ac_conn(:get, "/", [{"origin", "foo"}])
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

  test "sanitize_opts/1" do
    msg = "credentials can't be allowed when the allowed origins are *"
    assert_raise ArgumentError, msg, fn ->
      Corsica.sanitize_opts(origins: "*", allow_credentials: true)
    end

    opts = Corsica.sanitize_opts(allow_methods: ~w(get PoSt))
    assert opts[:allow_methods] == ~w(GET POST)
  end

  test "matches correctly" do
    conn = ac_conn(:get, "/bar", [{"origin", "foo.com"}]) |> Matching.call([])
    assert resp_header(conn, "access-control-allow-origin") == "*"
    assert resp_header(conn, "access-control-allow-credentials") == nil

    conn = ac_conn(:get, "/wildcard/foobar", [{"origin", "bar.com"}]) |> Matching.call([])
    assert resp_header(conn, "access-control-allow-origin") == "*"
    assert resp_header(conn, "access-control-allow-credentials") == "true"

    # When a request doesn't match, no CORS headers are returned.
    conn = ac_conn(:get, "/cardwild/foo", [{"origin", "baz.com"}]) |> Matching.call([])
    refute resp_header(conn, "access-control-allow-origin")
  end

  test "options can be passed to `use/2` and then overridden" do
    conn = ac_conn(:get, "/all", [{"origin", "foo.bar"}]) |> Options.call([])
    assert resp_header(conn, "access-control-allow-origin") == "*"

    conn = ac_conn(:get, "/only-some-origins", [{"origin", "b.a"}]) |> Options.call([])
    assert resp_header(conn, "access-control-allow-origin") == "b.a"

    conn = ac_conn(:get, "/only-some-origins", [{"origin", "not.allowed"}]) |> Options.call([])
    assert resp_header(conn, "access-control-allow-origin") == "a.b"
  end

  test "preflight requests: valid method" do
    headers = [{"origin", "a.b"}, {"access-control-request-method", "PUT"}]
    conn = ac_conn(:options, "/foo", headers) |> Preflight.call([])

    assert conn.status == 200
    assert conn.resp_body == ""
    assert resp_header(conn, "access-control-allow-methods") == "PUT, PATCH"
    assert resp_header(conn, "access-control-allow-headers") == "x-header, x-other-header"
    assert resp_header(conn, "access-control-allow-origin") == "*"
    assert resp_header(conn, "access-control-max-age") == "300"
  end

  test "preflight requests: invalid method" do
    headers = [{"origin", "a.b"}, {"access-control-request-method", "OPTIONS"}]
    conn = ac_conn(:options, "/foo", headers) |> Preflight.call([])

    refute conn.status
    refute resp_header(conn, "access-control-allow-methods")
    refute resp_header(conn, "access-control-allow-headers")
    refute resp_header(conn, "access-control-allow-origin")
    refute resp_header(conn, "access-control-max-age")
  end

  test "preflight requests: valid headers" do
    headers = [{"origin", "a.b"},
               {"access-control-request-method", "PATCH"},
               {"access-control-request-headers", "X-Other-Header, X-Header"}]
    conn = ac_conn(:options, "/foo", headers) |> Preflight.call([])

    assert conn.status == 200
    assert resp_header(conn, "access-control-allow-methods") == "PUT, PATCH"
    assert resp_header(conn, "access-control-allow-headers") == "x-header, x-other-header"
    assert resp_header(conn, "access-control-allow-origin") == "*"
    assert resp_header(conn, "access-control-max-age") == "300"
  end

  test "preflight requests: invalid headers" do
    headers = [{"origin", "a.b"},
               {"access-control-request-method", "PATCH"},
               {"access-control-request-headers", "X-Evil-Header, X-Header"}]
    conn = ac_conn(:options, "/foo", headers) |> Preflight.call([])

    refute conn.status
    refute resp_header(conn, "access-control-allow-methods")
    refute resp_header(conn, "access-control-allow-headers")
    refute resp_header(conn, "access-control-allow-origin")
    refute resp_header(conn, "access-control-max-age")
  end

  test "regex origins" do
    conn = ac_conn(:get, "/regex", [{"origin", "http://foo.com"}]) |> Options.call([])
    assert resp_header(conn, "access-control-allow-origin") == "http://foo.com"

    conn = ac_conn(:get, "/regex", [{"origin", "http://baz.com"}]) |> Options.call([])
    assert resp_header(conn, "access-control-allow-origin") == "foo.com"
  end

  test "explicit Access-Control-Allow-Origin header" do
    conn = ac_conn(:get, "/allow_origin", [{"origin", "non-allowed.com"}]) |> Options.call([])
    assert resp_header(conn, "access-control-allow-origin") == "custom-origin.com"
  end

  test "Vary header when the origin isn't *" do
    conn = ac_conn(:get, "/only-some-origins", [{"origin", "a.b"}]) |> Options.call([])
    assert resp_header(conn, "vary") == "origin"

    conn = ac_conn(:get, "/only-some-origins", [{"origin", "a.b"}])
            |> put_resp_header("vary", "host")
            |> Options.call([])
    assert resp_header(conn, "vary") == "origin, host"
  end

  test "credentials" do
    conn = ac_conn(:get, "/credentials", [{"origin", "foo.com"}]) |> Options.call([])
    assert resp_header(conn, "access-control-allow-origin") == "*"
    assert resp_header(conn, "access-control-allow-credentials") == "true"
  end

  test "as a plug" do
    conn = ac_conn(:get, "/foo", [{"origin", "foo.com"}]) |> AsPlug.call([])
    assert conn.status == 200
    assert conn.resp_body == "match"
    assert resp_header(conn, "access-control-allow-origin") == "foo.com"

    conn = ac_conn(:get, "/wildcard/anything", [{"origin", "foo.com"}]) |> AsPlug.call([])
    assert conn.status == 200
    assert conn.resp_body == "match"
    assert resp_header(conn, "access-control-allow-origin") == "foo.com"

    conn = ac_conn(:get, "/bar", [{"origin", "foo.com"}]) |> AsPlug.call([])
    assert conn.status == 200
    assert conn.resp_body == "match"
    refute resp_header(conn, "access-control-allow-origin")
  end

  defp ac_conn(method, path, headers) do
    conn(method, path, "", headers: [{"content-type", "text/plain"}|headers])
  end

  defp resp_header(conn, header) do
    case get_resp_header(conn, header) do
      []       -> nil
      [header] -> header
      headers  -> headers
    end
  end
end
