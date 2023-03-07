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
    decision_point = Map.get(by_id, alternatives_id)

    select_matching_condition = fn condition ->

      case Enum.find(decision_point.options, fn o -> o["name"] == condition end) do
        nil -> []

        %{"id" => option_id} ->
          Enum.map(children, fn alt ->
            if alt["value"] == option_id do
              %Selection{alternative: alt}
            else
              %Selection{alternative: alt, hidden: true}
            end
          end)
      end
    end

    # First read section level extrinsic state, where the results of condition code
    # assignment may have already been cached.
    case ExtrinsicState.read_section(
           user.id,
           section_slug,
           MapSet.new([pref_key])
         ) do
      {:ok, %{^pref_key => pref}} ->
        # We got a cached condition code, select the material pertaining to that condition
        select_matching_condition.(pref)

      _ ->
        # No cached condition code, so we need to
        case Oli.Delivery.Experiments.enroll(enrollment_id, project_slug, decision_point.title) do

          # When an experiment has already ended, we will default to showing the
          # first option.
          {:ok, nil} ->

            [first | _rest] = decision_point.options

            # Cache this result to avoid further queries to Upgrade
            ExtrinsicState.upsert_section(user.id, section_slug, Map.put(%{}, pref_key, first["name"]))
            display_first(children)

          {:ok, condition} ->

            # We got a code, cache it, and select the material pertaining to it
            ExtrinsicState.upsert_section(user.id, section_slug, Map.put(%{}, pref_key, condition))
            select_matching_condition.(condition)

          _ ->
            display_first(children)
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
