defmodule Corsica.DSL do
  alias Corsica.Helpers

  @doc false
  defmacro __using__(opts) do
    quote do
      @global_opts unquote(opts)

      import unquote(__MODULE__), only: [resources: 1, resources: 2]
      Module.register_attribute(__MODULE__, :resources, accumulate: true)

      @behaviour Plug
      @before_compile unquote(__MODULE__)

      # Plug callbacks.

      def init(_opts), do: []

      def call(conn, _opts) do
        if Corsica.cors_request?(conn) do
          handle_req(conn)
        else
          conn
        end
      end
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    resources   = Module.get_attribute(env.module, :resources)
    global_opts = Module.get_attribute(env.module, :global_opts)

    single_resources = Enum.flat_map(resources, &split_routes/1)

    routes = for {route, opts} <- single_resources do
      opts = Keyword.merge(global_opts, opts) |> Corsica.sanitize_opts
      compile_resource(route, opts)
    end

    if Enum.find(single_resources, &match?({:any, _}, &1)) do
      routes
    else
      last_match = quote do
        defp handle_req(conn), do: conn
      end

      routes ++ [last_match]
    end
  end

  @doc """
  """
  defmacro resources(resources, opts \\ []) do
    quote do
      @resources {unquote(resources), unquote(Macro.escape(opts))}
    end
  end

  # Compiling helpers.

  defp compile_resource(route, opts) do
    compiled = Helpers.compile_route(route)
    quote do
      defp handle_req(%Plug.Conn{path_info: unquote(compiled)} = conn) do
        Corsica.handle_req(conn, unquote(opts))
      end
    end
  end

  defp split_routes({:all, _opts} = route),
    do: [route]
  defp split_routes({routes, opts}),
    do: Enum.map(routes, &({&1, opts}))
end
