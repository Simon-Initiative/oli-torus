defmodule Oli.Delivery.Gating.Strategies.Schedule do
  @moduledoc """
  Schedule strategy provides a temporal based gating condition. A schedule condition
  can define a start and/or end datetime for a resource to be available.
  """
  alias Oli.Delivery.Gating.GatingCondition
  alias Oli.Delivery.Gating.GatingConditionData
  alias Oli.Delivery.Sections
  alias Oli.Publishing.DeliveryResolver

  @behaviour Oli.Delivery.Gating.Strategies.Strategy

  def type do
    :schedule
  end

  def check(%GatingCondition{
        data: %GatingConditionData{start_datetime: start_datetime, end_datetime: end_datetime}
      }) do
    now = DateTime.utc_now()

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
  end

  def reason(
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
      Keyword.get(opts, :format_datetime, fn dt ->
        Timex.format!(dt, "{M}/{D}/{YYYY} at {h12}:{m}:{s} {AM}")
      end)

    cond do
      start_datetime != nil && DateTime.compare(start_datetime, now) != :lt ->
        "#{revision.title} is not available before #{format_datetime.(start_datetime)}"

      end_datetime != nil && DateTime.compare(now, end_datetime) != :lt ->
        "#{revision.title} is not available after #{format_datetime.(end_datetime)}"

      true ->
        "An error occurred. Please try again."
    end
  end
end
