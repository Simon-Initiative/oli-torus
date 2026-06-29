defmodule Oli.Resources.Alternatives.DecisionPointStrategy do
  alias Oli.Experiments.{
    AssignmentDecision,
    AssignConditionRequest,
    RecordExposureRequest,
    Scope
  }

  alias Oli.Resources.Alternatives.AlternativesStrategyContext
  alias Oli.Resources.Alternatives.Selection

  require Logger

  @behaviour Oli.Resources.Alternatives.AlternativesStrategy

  @doc """
  Uses A/B testing assignment for a delivery decision point and falls back to the
  first option when no active experiment applies.
  """
  def select(
        %AlternativesStrategyContext{
          enrollment_id: enrollment_id,
          user: user,
          project_slug: project_slug,
          section_slug: section_slug,
          mode: :delivery,
          alternative_groups_by_id: by_id
        },
        %{
          "children" => children,
          "alternatives_id" => alternatives_id
        }
      ) do
    decision_point = Map.get(by_id, alternatives_id)

    with {:ok, %AssignmentDecision{status: :assigned} = decision} <-
           assign_condition(project_slug, section_slug, user, enrollment_id, decision_point),
         :ok =
           maybe_record_exposure(
             decision,
             project_slug,
             section_slug,
             user,
             enrollment_id,
             decision_point
           ),
         selections when selections != [] <-
           select_matching_condition(children, decision_point, decision.condition_code) do
      selections
    else
      {:ok, %AssignmentDecision{status: :no_experiment}} ->
        display_first(children)

      {:error, error} ->
        Logger.warning("A/B testing assignment fell back to first option: #{inspect(error)}")

        display_first(children)

      [] ->
        display_first(children)

      _ ->
        display_first(children)
    end
  end

  def select(_, %{"children" => children}), do: display_first(children)

  defp assign_condition(project_slug, section_slug, user, enrollment_id, decision_point) do
    Oli.Experiments.assign_condition(%AssignConditionRequest{
      scope: scope(project_slug, section_slug, user.id, enrollment_id),
      alternatives_resource_id: decision_point.id,
      alternatives_revision_id: decision_point.revision_id,
      decision_point_key: decision_point_key(decision_point.id),
      available_condition_codes: Enum.map(decision_point.options, & &1["name"])
    })
  end

  defp maybe_record_exposure(
         %AssignmentDecision{assignment_id: assignment_id},
         project_slug,
         section_slug,
         user,
         enrollment_id,
         decision_point
       ) do
    case Oli.Experiments.record_exposure(%RecordExposureRequest{
           scope: scope(project_slug, section_slug, user.id, enrollment_id),
           assignment_id: assignment_id,
           content_revision_id: decision_point.revision_id,
           idempotency_key:
             "alternatives:#{decision_point.id}:#{decision_point.revision_id}:#{enrollment_id}"
         }) do
      {:ok, _receipt} ->
        :ok

      {:error, error} ->
        Logger.warning("A/B testing exposure recording failed: #{inspect(error)}")
        :ok
    end
  end

  defp scope(project_slug, section_slug, user_id, enrollment_id) do
    %Scope{
      institution_id: institution_id(section_slug),
      project_slug: project_slug,
      section_slug: section_slug,
      user_id: user_id,
      enrollment_id: enrollment_id
    }
  end

  defp institution_id(section_slug) do
    case Oli.Delivery.Sections.get_section_by(slug: section_slug) do
      nil -> nil
      section -> section.institution_id
    end
  end

  defp decision_point_key(alternatives_resource_id),
    do: "alternatives:#{alternatives_resource_id}"

  defp select_matching_condition(children, decision_point, condition) do
    case Enum.find(decision_point.options, fn o -> o["name"] == condition end) do
      nil ->
        []

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
