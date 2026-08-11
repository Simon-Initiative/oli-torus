defmodule Oli.Resources.Alternatives do
  @moduledoc """
  Resolves and selects versioned Alternatives groups.

  New experiment-controlled revisions persist `experiment_controlled`; the historical
  `upgrade_decision_point` value remains a read/ingest alias.
  """
  alias Oli.Resources.Alternatives.AlternativesStrategyContext
  alias Oli.Resources.Alternatives.SelectAllStrategy
  alias Oli.Resources.Alternatives.UserSectionPreferenceStrategy
  alias Oli.Resources.Alternatives.DecisionPointStrategy

  @doc """
  Selects one or more alternatives using the element's specified strategy.

  Returns a list of `Oli.Resources.Alternatives.Selection` structs.
  """
  def select(
        %AlternativesStrategyContext{alternative_groups_by_id: by_id} = context,
        %{"alternatives_id" => alternatives_id} = alternatives_element
      ) do
    strategy_name =
      by_id |> Map.get(alternatives_id) |> Map.fetch!(:strategy) |> normalize_strategy!()

    strategy(strategy_name).select(context, alternatives_element)
  end

  @doc """
  Prepares experiment-backed alternatives decisions for delivery before page rendering.

  Returns `{decisions_by_alternatives_id, attribution_payloads}`. The decision map
  is consumed by `select/2` during rendering so that delivery render does not need
  to assign learners or record exposure.
  """
  def prepare_delivery_decisions(%AlternativesStrategyContext{} = context, content) do
    DecisionPointStrategy.prepare_delivery_decisions(context, content)
  end

  @doc """
  Normalizes a persisted Alternatives strategy.

  Returns `{:ok, strategy}` for supported values and `{:error, :unsupported_strategy}`
  for unknown input so callers fail closed.
  """
  def normalize_strategy("upgrade_decision_point"), do: {:ok, "experiment_controlled"}
  def normalize_strategy("experiment_controlled"), do: {:ok, "experiment_controlled"}
  def normalize_strategy("select_all"), do: {:ok, "select_all"}
  def normalize_strategy("user_section_preference"), do: {:ok, "user_section_preference"}
  def normalize_strategy(_strategy), do: {:error, :unsupported_strategy}

  defp normalize_strategy!(strategy) do
    case normalize_strategy(strategy) do
      {:ok, normalized} -> normalized
      {:error, :unsupported_strategy} -> raise ArgumentError, "unsupported Alternatives strategy"
    end
  end

  defp strategy("select_all"), do: SelectAllStrategy

  defp strategy("user_section_preference"), do: UserSectionPreferenceStrategy

  defp strategy("upgrade_decision_point"), do: DecisionPointStrategy
  defp strategy("experiment_controlled"), do: DecisionPointStrategy
end
