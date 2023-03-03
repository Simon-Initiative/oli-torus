defmodule Oli.Resources.Alternatives.DecisionPointStrategy do
  alias Oli.Resources.Alternatives.AlternativesStrategyContext
  alias Oli.Delivery.ExtrinsicState
  alias Oli.Resources.Alternatives.Selection

  require Logger

  @behaviour Oli.Resources.Alternatives.AlternativesStrategy

  @doc """
  Issues a request to Upgrade to assign the user to an experiment condition. Stores
  that result in section extrinsic state afterwards so that we do not make additional,
  unecessary calls to Upgrade after the condition has been assigned.
  """
  def select(
        %AlternativesStrategyContext{enrollment_id: enrollment_id, user: user, project_slug: project_slug, section_slug: section_slug, mode: :delivery, alternative_groups_by_id: by_id},
        %{
          "children" => children,
          "alternatives_id" => alternatives_id
        }
      ) do

    pref_key = ExtrinsicState.Key.alternatives_preference(alternatives_id)
    decision_point = Map.get(by_id, alternatives_id).title

    select_matching_condition = fn condition ->
      Enum.map(children, fn alt ->
        if alt["value"] == condition do
          %Selection{alternative: alt}
        else
          %Selection{alternative: alt, hidden: true}
        end
      end)
    end

    case ExtrinsicState.read_section(
           user.id,
           section_slug,
           MapSet.new([pref_key])
         ) do
      {:ok, %{^pref_key => pref}} ->
        # return all children with display: :none except for the alternative that matches the selected preference
        select_matching_condition.(pref)

      _ ->
        case Oli.Delivery.Experiments.enroll(enrollment_id, project_slug, decision_point) do
          {:ok, condition} ->
            ExtrinsicState.upsert_section(user.id, section_slug, Map.put(%{}, pref_key, condition))
            select_matching_condition.(condition)

          _ -> display_first(children)
        end

    end

  end

  def select(_, %{"children" => children}), do: display_first(children)

  defp display_first(children) do
    case children do
      [] ->
        Logger.error("Alternatives element does not have any alternatives specified")
        []

      [first | rest] ->
        [
          %Selection{alternative: first}
          | Enum.map(rest, fn alt -> %Selection{alternative: alt, hidden: true} end)
        ]
    end
  end
end
