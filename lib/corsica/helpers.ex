defmodule Corsica.Helpers do
  @moduledoc false

  @doc """
  Compiles a route into a pattern-matchable list.
  """
  def compile_route(:all), do: quote(do: _)
  def compile_route(route) do
    route = route |> String.split("/") |> Enum.reject(&match?("", &1))
    cond do
      route == ["*"] ->
        quote(do: _)
      List.last(route) == "*" ->
        route = List.delete_at(route, -1)
        quote(do: [unquote_splicing(route)|_])
      true ->
        route
    end
  end
end
