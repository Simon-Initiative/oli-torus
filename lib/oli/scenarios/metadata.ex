defmodule Oli.Scenarios.Metadata do
  @moduledoc """
  Reads optional scenario-level metadata from YAML scenario files.
  """

  defstruct tags: [], timeout_ms: nil, reason: nil

  @type t :: %__MODULE__{
          tags: [String.t()],
          timeout_ms: non_neg_integer() | nil,
          reason: String.t() | nil
        }

  @doc """
  Reads scenario metadata from a YAML file.

  Metadata is optional. Files without a top-level `scenario` key return the default metadata.
  """
  @spec from_file(String.t()) :: t()
  def from_file(path) do
    path
    |> File.read!()
    |> from_yaml()
  end

  @doc """
  Reads scenario metadata from YAML content.
  """
  @spec from_yaml(String.t()) :: t()
  def from_yaml(yaml_content) when is_binary(yaml_content) do
    yaml_content
    |> YamlElixir.read_from_string!()
    |> from_data()
  end

  @doc """
  Reads scenario metadata from parsed YAML data.
  """
  @spec from_data(any()) :: t()
  def from_data(%{"scenario" => scenario}) when is_map(scenario) do
    %__MODULE__{
      tags: parse_tags(scenario["tags"]),
      timeout_ms: scenario["timeout_ms"],
      reason: scenario["reason"]
    }
  end

  def from_data(_), do: %__MODULE__{}

  defp parse_tags(nil), do: []

  defp parse_tags(tags) when is_list(tags) do
    Enum.map(tags, &to_string/1)
  end
end
