defmodule Oli.Delivery.Proficiency do
  @moduledoc """
  Model-neutral read boundary for learner proficiency.

  The persisted `Section.learning_model_version` is the only dispatch input.
  In particular, `analytics_version` controls analytics infrastructure and must
  never select a proficiency model. Provider implementations are introduced in
  the next delivery phase; until then these APIs fail explicitly when invoked.
  """

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section

  @type objective_id :: pos_integer()
  @type user_id :: pos_integer()
  @type scope :: {:page, pos_integer()} | {:container, pos_integer()} | :course
  @type reason ::
          {:unsupported_learning_model, term()}
          | {:invalid_option, atom()}
          | {:provider_unavailable, :naive | :lkt_aoa}

  @provider_by_model %{
    naive: Oli.Delivery.Proficiency.Naive,
    lkt_aoa: Oli.Delivery.Proficiency.LktAoa
  }

  @doc "Returns the provider fixed by the Section's persisted model selection."
  @spec provider_for(Section.t()) :: {:ok, module()} | {:error, reason()}
  def provider_for(%Section{learning_model_version: model}) do
    case Map.fetch(provider_by_model(), model) do
      {:ok, provider} -> {:ok, provider}
      :error -> {:error, {:unsupported_learning_model, model}}
    end
  end

  # Dependency configuration may replace a provider implementation in tests,
  # but the persisted model remains the immutable key used for selection.
  defp provider_by_model do
    Application.get_env(:oli, :proficiency_providers, @provider_by_model)
  end

  @spec estimates_for_objectives(
          Section.t() | pos_integer(),
          [user_id()],
          [objective_id()],
          keyword()
        ) ::
          {:ok, map()} | {:error, reason()}
  def estimates_for_objectives(section, user_ids, objective_ids, opts \\ [])

  def estimates_for_objectives(section_id, user_ids, objective_ids, opts)
      when is_integer(section_id) do
    section_id
    |> Sections.get_section!()
    |> estimates_for_objectives(user_ids, objective_ids, opts)
  end

  def estimates_for_objectives(%Section{} = section, user_ids, objective_ids, opts) do
    dispatch(section, :estimates_for_objectives, [user_ids, objective_ids, opts], opts)
  end

  @spec estimates_for_scopes(Section.t() | pos_integer(), [user_id()], [scope()], keyword()) ::
          {:ok, map()} | {:error, reason()}
  def estimates_for_scopes(section, user_ids, scopes, opts \\ [])

  def estimates_for_scopes(section_id, user_ids, scopes, opts) when is_integer(section_id) do
    section_id
    |> Sections.get_section!()
    |> estimates_for_scopes(user_ids, scopes, opts)
  end

  def estimates_for_scopes(%Section{} = section, user_ids, scopes, opts) do
    dispatch(section, :estimates_for_scopes, [user_ids, scopes, opts], opts)
  end

  @spec objective_aggregates(Section.t() | pos_integer(), [objective_id()], keyword()) ::
          {:ok, map()} | {:error, reason()}
  def objective_aggregates(section, objective_ids, opts \\ [])

  def objective_aggregates(section_id, objective_ids, opts) when is_integer(section_id) do
    section_id
    |> Sections.get_section!()
    |> objective_aggregates(objective_ids, opts)
  end

  def objective_aggregates(%Section{} = section, objective_ids, opts) do
    dispatch(section, :objective_aggregates, [objective_ids, opts], opts)
  end

  @spec scope_aggregates(Section.t() | pos_integer(), [scope()], keyword()) ::
          {:ok, map()} | {:error, reason()}
  def scope_aggregates(section, scopes, opts \\ [])

  def scope_aggregates(section_id, scopes, opts) when is_integer(section_id) do
    section_id
    |> Sections.get_section!()
    |> scope_aggregates(scopes, opts)
  end

  def scope_aggregates(%Section{} = section, scopes, opts) do
    dispatch(section, :scope_aggregates, [scopes, opts], opts)
  end

  @doc "Returns the provider-correct objective membership for a delivery scope."
  def objective_ids_for_scope(%Section{} = section, scope) do
    dispatch(section, :objective_ids_for_scope, [scope], [])
  end

  def page_ids(%Section{} = section), do: dispatch(section, :page_ids, [], [])

  def user_ids_for_objectives(%Section{} = section, objective_ids),
    do: dispatch(section, :user_ids_for_objectives, [objective_ids], [])

  def user_ids_for_scopes(%Section{} = section, scopes, opts \\ []),
    do: dispatch(section, :user_ids_for_scopes, [scopes, opts], opts)

  def labels_for_pages(%Section{} = section, page_ids, user_ids),
    do: dispatch(section, :labels_for_pages, [page_ids, user_ids], [])

  @doc "Classifies an aggregate score according to the Section-selected provider."
  def label_for_score(%Section{} = section, score, attempt_count \\ 3),
    do: dispatch(section, :label_for_score, [score, attempt_count], [])

  # A model option would create two competing sources of truth. Reject it before
  # provider lookup so a caller cannot accidentally mix models within one view.
  defp dispatch(section, operation, args, opts) do
    with :ok <- reject_model_override(opts),
         {:ok, provider} <- provider_for(section),
         true <- provider_available?(provider, operation, length(args) + 1) do
      apply(provider, operation, [section | args])
    else
      false -> {:error, {:provider_unavailable, section.learning_model_version}}
      {:error, _reason} = error -> error
    end
  end

  # `function_exported?/3` alone returns false for an implementation that exists
  # but has not yet been loaded, which would make the first request after boot fail.
  defp provider_available?(provider, operation, arity) do
    case Code.ensure_loaded(provider) do
      {:module, ^provider} -> function_exported?(provider, operation, arity)
      {:error, _reason} -> false
    end
  end

  defp reject_model_override(opts) do
    case Enum.find([:model, :learning_model_version], &Keyword.has_key?(opts, &1)) do
      nil -> :ok
      option -> {:error, {:invalid_option, option}}
    end
  end
end
