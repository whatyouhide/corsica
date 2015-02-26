defmodule Corsica.DSL do
  @moduledoc """
  Provides a very simple and small DSL for defining CORS plugs.
  """

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

    if Enum.find(single_resources, &match?({:all, _}, &1)) do
      routes
    else
      last_match = quote do
        defp handle_req(conn), do: conn
      end

      routes ++ [last_match]
    end
  end

  @doc """
  Registers a list of CORS-enabled resources.

  This macro registers a list of resources on which CORS is enabled. The
  resources have to be strings, but `*` wildcards can be used (they will match
  anything only if used **at the end of the resource**). This behaviour tries to
  be very similar to the behaviour of
  [`Plug.Router`](https://hexdocs.pm/plug/Plug.Router.html).

  The special atom `:all` can be passed instead of a list; in this case,
  everything matches.

  The reason why only strings can be used (instead of regexes) is that routes
  are compiled to function heads with pattern matching, which is very efficient
  (that's why also Plug and Phoenix do this). This is also the reason why
  wildcard matches can only appear at the end (they get converted to
  `["any"|_]` matches).

  ## Examples

      # Will match only "/foo" or "/bar"
      resources ["/foo", "/bar"]

      # Will match "/any/thing" and "/any/thingy/thing" but not "/thing/any"
      resources ["/any/*"]

      # Will match everything
      resources :all

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
