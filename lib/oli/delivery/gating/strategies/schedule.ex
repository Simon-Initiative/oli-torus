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

  def can_access?(%GatingCondition{
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

  def access_details(
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

    format_datetime = Keyword.get(opts, :format_datetime, &format_datetime_default/1)

    case {start_datetime, end_datetime} do
      {nil, nil} ->
        {:granted}

      {start_datetime, nil} ->
        if DateTime.compare(start_datetime, now) == :lt do
          {:granted}
        else
          {:blocked,
           "#{revision.title} is not scheduled to start until #{format_datetime.(start_datetime)}"}
        end

      {nil, end_datetime} ->
        if DateTime.compare(now, end_datetime) == :lt do
          {:granted}
        else
          {:blocked,
           "#{revision.title} was scheduled to end at #{format_datetime.(end_datetime)}"}
        end

      {start_datetime, end_datetime} ->
        if DateTime.compare(start_datetime, now) == :lt and
             DateTime.compare(now, end_datetime) == :lt do
          {:granted}
        else
        end
    end
  end

  defp format_datetime_default(%DateTime{} = dt) do
    Timex.format!(dt, "{M}/{D}/{YYYY} {h12}:{m}:{s} {AM} {Zabbr}")
  end
end
