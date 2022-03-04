defmodule Oli.Delivery.Gating.ConditionTypes.Started do
  @moduledoc """
  Started strategy provides a condition that requires a source resource to have at least
  one attempt present.
  """

  alias Oli.Delivery.Gating.GatingCondition
  alias Oli.Delivery.Gating.GatingConditionData
  alias Oli.Delivery.Gating.ConditionTypes.ConditionContext
  alias Oli.Delivery.Sections
  alias Oli.Publishing.DeliveryResolver

  @behaviour Oli.Delivery.Gating.ConditionTypes.ConditionType

  def type do
    :started
  end

  def evaluate(
        %GatingCondition{
          data: %GatingConditionData{resource_id: resource_id}
        },
        %ConditionContext{} = context
      ) do
    {resource_accesses, context} = ConditionContext.resource_accesses(context)

    # A resource is 'started' if at least one resource attempt is present. It
    # isn't enough to simply check for an existence of a resource access record
    # because graded pages have the possibility that only the prologue was visited

    result =
      case Map.get(resource_accesses, resource_id) do
        nil -> false
        %{resource_attempts_count: 0} -> false
        _ -> true
      end

    {result, context}
  end

  def details(
        %GatingCondition{
          section_id: section_id,
          resource_id: resource_id,
          data: %GatingConditionData{
            resource_id: source_id
          }
        },
        _ \\ []
      ) do
    section = Sections.get_section!(section_id)

    [revision, revision_source] =
      DeliveryResolver.from_resource_id(section.slug, [resource_id, source_id])

    "#{revision.title} cannot be accessed until #{revision_source.title} is started"
  end
end
