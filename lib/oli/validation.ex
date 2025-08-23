defmodule Oli.Validation do
  @moduledoc """
  Context for validating data structures, particularly activity models and content elements.
  """

  alias Oli.Activities.Model
  alias Oli.Validation.ContentValidator

  @doc """
  Validates a complete activity model, including both high-level structure
  and content element schema validation.

  ## Parameters
  - `activity_map`: A map with string keys representing the activity data

  ## Returns
  - `{:ok, parsed_model}` if validation succeeds
  - `{:error, reason}` if validation fails

  ## Examples

      iex> activity = %{
      ...>   "stem" => %{
      ...>     "content" => [%{"type" => "p", "children" => [%{"text" => "Question text"}]}]
      ...>   },
      ...>   "authoring" => %{
      ...>     "parts" => [%{
      ...>       "hints" => [%{
      ...>         "content" => [%{"type" => "p", "children" => [%{"text" => "Hint text"}]}]
      ...>       }]
      ...>     }]
      ...>   }
      ...> }
      iex> Oli.Validation.validate_activity(activity)
      {:ok, %Oli.Activities.Model{...}}
  """
  def validate_activity(activity_map) when is_map(activity_map) do
    # First validate the high-level structure
    case Model.parse(activity_map) do
      {:ok, parsed_model} ->
        # Then validate content elements with JSON schema
        case ContentValidator.validate_activity_content(activity_map) do
          :ok -> {:ok, parsed_model}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}

      error ->
        error
    end
  end

  def validate_activity(_), do: {:error, "Activity must be a map"}
end
