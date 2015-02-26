defmodule Corsica.Helpers do
  @moduledoc false

  @doc """
  Compiles a route into a pattern-matchable list.

  If the `:all` atom is given, a wildcard match (`_`) is returned.

  ## Examples

      iex> compile_route :all
      {:_, [], Elixir}

      iex> compile_route "/foo/bar"
      ["foo", "bar"]

      iex> compile_route "/wildcard/*"
      ["wildcard", {:_, [], Elixir}]

  """
  def compile_route(:all), do: quote(do: _)
  def compile_route(route) do
    route
    |> String.split("/")
    |> Enum.reject(&match?("", &1))
    |> Enum.map(&replace_wildcard/1)
  end

  defp replace_wildcard("*"), do: quote(do: _)
  defp replace_wildcard(any), do: any
end
