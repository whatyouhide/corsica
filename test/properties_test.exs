if Code.ensure_compiled?(ExUnitProperties) do
  defmodule Corsica.PropertiesTest do
    use ExUnit.Case, async: true
    use ExUnitProperties
    use Plug.Test

    import Corsica

    property "cors_req?/1" do
      check all conn <- conn(),
                origin <- url() do
        assert cors_req?(conn) == false
        assert cors_req?(put_origin(conn, origin)) == true
      end
    end

    property "preflight_req?/1" do
      check all conn <- conn(),
                url <- url() do
        assert preflight_req?(conn) == false
        assert preflight_req?(put_origin(conn, url)) == false
      end

      check all conn <- conn(method: :options),
                url <- url() do
        assert conn
               |> put_origin(url)
               |> put_req_header("access-control-request-method", "GET")
               |> preflight_req?()

        refute conn
               |> put_req_header("access-control-request-method", "GET")
               |> preflight_req?()
      end
    end

    defp conn(options \\ []) do
      import StreamData

      method_generator =
        cond do
          method = options[:method] ->
            constant(method)

          true ->
            request_method()
        end

      gen all method <- method_generator,
              path <- map(string(:alphanumeric), &("/" <> &1)) do
        conn(method, path)
      end
    end

    defp url() do
      import StreamData

      scheme = one_of([constant("http"), constant("https")])

      map({scheme, string(:alphanumeric), string(:alphanumeric)}, fn {scheme, domain, tld} ->
        "#{scheme}://#{domain}.#{tld}"
      end)
    end

    defp request_method() do
      StreamData.member_of(~w(get post put head delete)a)
    end

    defp put_origin(conn, origin), do: put_req_header(conn, "origin", origin)
  end
end
