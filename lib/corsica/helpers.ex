defmodule Corsica.Helpers do
  @moduledoc false

  @doc """
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
