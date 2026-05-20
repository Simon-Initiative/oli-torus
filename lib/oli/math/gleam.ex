defmodule Oli.Math.Gleam do
  @moduledoc false

  @gleam_erlang_build Path.expand("../../../gleam/build/dev/erlang", __DIR__)

  def call(module, function, args) do
    ensure_gleam_code_path!()
    apply(module, function, args)
  end

  defp ensure_gleam_code_path! do
    # The Mix project compiles Gleam and its Gleam package dependencies under
    # `gleam/build`. Add every generated ebin path here so wrappers can call the
    # public Gleam boundary without copying generated artifacts into Torus.
    @gleam_erlang_build
    |> Path.join("*/ebin")
    |> Path.wildcard()
    |> Enum.each(&add_code_path/1)
  end

  defp add_code_path(path) do
    charlist_path = String.to_charlist(path)

    case charlist_path in :code.get_path() do
      true ->
        :ok

      false ->
        :code.add_patha(charlist_path)
        :ok
    end
  end
end
