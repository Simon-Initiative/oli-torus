defmodule Oli.Validation do
  @moduledoc """
  Context for validating data structures, particularly activity models and content elements.
  """

  alias Oli.Activities.Model
  alias Oli.Validation.ContentValidator
  alias Oli.Utils.{JSONValidation, SchemaResolver}

  @doc """
  Validates an authored activity against its explicitly selected JSON Schema.

  Supports all activity types with manifests under
  `assets/src/components/activities`, selected by their exact manifest ID. Returns
  `:ok` or JSON Pointer/message errors without parsing, migrating, or casting
  the model. Unknown activity types return an error. This opt-in API does not
  change the legacy `validate_activity/1` or any save/ingest validation boundary.

  Schemas and their shared rich-content references are built once per schema
  registry revision and reused on subsequent calls. JSON Schema checks structure;
  rule evaluation and cross-reference integrity remain separate domain concerns.
  """
  @spec validate_activity_schema(String.t(), term()) ::
          :ok | {:error, [JSONValidation.error()] | String.t()}
  def validate_activity_schema(type_slug, activity_map) do
    case Oli.Validation.ActivityContracts.fetch(type_slug) do
      {:ok, %{schema: name}} ->
        name |> SchemaResolver.resolve() |> JSONValidation.validate(activity_map)

      :error ->
        {:error, "No JSON schema registered for activity type: #{inspect(type_slug)}"}
    end
  end

  @doc """
  Runs separate, non-mutating domain checks on a schema-valid Basic Page activity.

  Checks logical ID uniqueness, response rule/configuration syntax, and terminal
  fallbacks for automatic server-evaluated parts. Adaptive is explicitly excluded.
  Returns structured, bounded JSON Pointer issues. This does not invoke JSON Schema,
  persist data, evaluate answers, or enforce scoring/reference-integrity policy.
  """
  @spec validate_activity_domain(String.t(), term()) ::
          :ok | {:error, [Oli.Validation.ActivityDomain.Issue.t()]}
  def validate_activity_domain(type_slug, model),
    do: Oli.Validation.ActivityDomain.validate(type_slug, model)

  @doc """
  Runs standalone domain validation on schema-valid Basic Page content.

  Checks IDs, activity-bank logic/counts, and resource existence/type using one
  caller-supplied bulk resolver. See `Oli.Validation.PageDomain.validate/2` for
  the resolver contract. JSON Schema validation remains a separate step.
  """
  @spec validate_page_domain(term(), Oli.Validation.PageDomain.resolver()) ::
          :ok | {:error, [Oli.Validation.ActivityDomain.Issue.t()]}
  def validate_page_domain(content, resolve_resources),
    do: Oli.Validation.PageDomain.validate(content, resolve_resources)

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
