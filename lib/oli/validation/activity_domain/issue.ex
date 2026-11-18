defmodule Oli.Validation.ActivityDomain.Issue do
  @moduledoc "Stable, JSON-serializable activity domain diagnostics."
  @derive Jason.Encoder
  defstruct [:code, :path, :message, related_paths: []]

  @type t :: %__MODULE__{
          code: String.t(),
          path: String.t(),
          message: String.t(),
          related_paths: [String.t()]
        }

  @doc "Creates a bounded diagnostic from reversed JSON path segments."
  def new(code, path, message, related \\ []) do
    %__MODULE__{
      code: code,
      path: pointer(path),
      message: String.slice(message, 0, 256),
      related_paths: Enum.map(related, &pointer/1)
    }
  end

  @doc "Encodes reversed segments as a JSON Pointer, escaping property names."
  def pointer([]), do: ""

  def pointer(path),
    do:
      "/" <>
        (path
         |> Enum.reverse()
         |> Enum.map_join("/", fn segment ->
           segment |> to_string() |> String.replace("~", "~0") |> String.replace("/", "~1")
         end))
end
