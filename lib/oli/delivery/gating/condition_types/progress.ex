defmodule Oli.Delivery.Gating.ConditionTypes.Progress do
  @moduledoc """
  The progress strategy provides a condition that requires a practice page type source resource to have a
  certain percentage of progress in its content.
  """

  alias Oli.Delivery.Gating.GatingCondition
  alias Oli.Delivery.Gating.GatingConditionData
  alias Oli.Delivery.Gating.ConditionTypes.ConditionContext
  alias Oli.Delivery.Sections
  alias Oli.Publishing.DeliveryResolver

  @behaviour Oli.Delivery.Gating.ConditionTypes.ConditionType

  def type do
    :progress
  end

  def evaluate(
        %GatingCondition{
          data: %GatingConditionData{
            resource_id: resource_id,
            minimum_percentage: minimum_percentage
          }
        },
        %ConditionContext{} = context
      ) do
    {resource_accesses, context} = ConditionContext.resource_accesses(context)

    result =
      case Map.get(resource_accesses, resource_id) do
        nil ->
          false

        %{resource_attempts_count: 0} ->
          false

        %{progress: progress} ->
          case minimum_percentage do
            nil -> true
            min -> progress >= min
          end
      end

    {result, context}
  end

  def details(
        %GatingCondition{
          section_id: section_id,
          resource_id: resource_id,
          data: %GatingConditionData{
            resource_id: source_id,
            minimum_percentage: minimum_percentage
          }
        },
        _ \\ []
      ) do
    section = Sections.get_section!(section_id)

    [revision, revision_source] =
      DeliveryResolver.from_resource_id(section.slug, [resource_id, source_id])

    case minimum_percentage do
      nil ->
        "#{revision.title} cannot be accessed until #{revision_source.title} is completed"

      min ->
        {percentage, _} = (min * 100) |> Float.to_string() |> Integer.parse()

        "#{revision.title} cannot be accessed until #{percentage}% of #{revision_source.title} activities have been completed"
    end
  end
end
