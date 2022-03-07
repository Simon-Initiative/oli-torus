defmodule Oli.Delivery.Gating.ConditionTypes.Schedule do
  @moduledoc """
  Schedule strategy provides a temporal based gating condition. A schedule condition
  can define a start and/or end datetime for a resource to be available.
  """

  alias Oli.Delivery.Gating.GatingCondition
  alias Oli.Delivery.Gating.GatingConditionData
  alias Oli.Delivery.Sections
  alias Oli.Publishing.DeliveryResolver

  @behaviour Oli.Delivery.Gating.ConditionTypes.ConditionType

  def type do
    :schedule
  end

  def evaluate(
        %GatingCondition{
          data: %GatingConditionData{start_datetime: start_datetime, end_datetime: end_datetime}
        },
        context
      ) do
    now = DateTime.utc_now()

    result =
      case {start_datetime, end_datetime} do
        {nil, nil} ->
          true

        {start_datetime, nil} ->
          DateTime.compare(start_datetime, now) == :lt

        {nil, end_datetime} ->
          DateTime.compare(now, end_datetime) == :lt

        {start_datetime, end_datetime} ->
          DateTime.compare(start_datetime, now) == :lt and
            DateTime.compare(now, end_datetime) == :lt
      end

    {result, context}
  end

  def details(
        %GatingCondition{
          section_id: section_id,
          resource_id: resource_id,
          data: %GatingConditionData{
            start_datetime: start_datetime,
            end_datetime: end_datetime
          }
        },
        opts \\ []
      ) do
    section = Sections.get_section!(section_id)
    revision = DeliveryResolver.from_resource_id(section.slug, resource_id)
    now = DateTime.utc_now()

    format_datetime =
      case Keyword.get(opts, :format_datetime) do
        nil -> throw("format_datetime opt is required")
        format_datetime -> format_datetime
      end

    cond do
      start_datetime != nil && DateTime.compare(start_datetime, now) != :lt ->
        "#{revision.title} is scheduled to start #{format_datetime.(start_datetime)}"

      end_datetime != nil && DateTime.compare(now, end_datetime) != :lt ->
        "#{revision.title} is scheduled to end #{format_datetime.(end_datetime)}"

      true ->
        nil
    end
  end
end
