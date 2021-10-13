defmodule Oli.Utils.DataGenerators.Sampler do
  defmacro sampler(name, data) do
    count = Enum.count(data)

    mapped_data =
      data |> Enum.with_index() |> Enum.into(%{}, fn {k, v} -> {v, k} end) |> Macro.escape()

    quote do
      def unquote(name)() do
        unquote(mapped_data)
        |> Map.get(:rand.uniform(unquote(count) - 1))
      end
    end
  end
end
