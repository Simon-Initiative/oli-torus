defmodule Oli.Delivery.Gating.ConditionTypes.Finished do
  @moduledoc """
  Finished strategy provides a condition that requires a source resource to have at least
  one completed attempt present, which optionally acheived a minimum score (as a percentage).
  """

  alias Oli.Delivery.Gating.GatingCondition
  alias Oli.Delivery.Gating.GatingConditionData
  alias Oli.Delivery.Gating.ConditionTypes.ConditionContext
  alias Oli.Delivery.Sections
  alias Oli.Publishing.DeliveryResolver

  @behaviour Oli.Delivery.Gating.ConditionTypes.ConditionType

  def type do
    :finished
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

    # A resource is 'finished' (aka at least one attempt has been completed) if the score
    # and out_of are not nil, and there is at least one resource attempt

    result =
      case Map.get(resource_accesses, resource_id) do
        nil ->
          false

        %{resource_attempts_count: 0} ->
          false

        %{score: nil, out_of: nil} ->
          false

        %{score: score, out_of: out_of} ->
          case minimum_percentage do
            nil -> true
            min -> score / out_of >= min
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

        "#{revision.title} cannot be accessed until #{revision_source.title} is completed with a minimum score of #{percentage}%"
    end
  end
end
