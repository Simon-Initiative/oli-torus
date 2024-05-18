defmodule Oli.Analytics.XAPI do
  alias Oli.Analytics.XAPI.StatementBundle

  @chars "abcdefghijklmnopqrstuvwxyz1234567890" |> String.split("", trim: true)

  def emit(%StatementBundle{} = bundle) do
    producer =
      Oli.Analytics.XAPI.UploadPipeline
      |> Broadway.producer_names()
      |> Enum.random()

    GenStage.cast(producer, {:insert, bundle})
  end

  def emit(category, events) when is_list(events) do
    context = hd(events) |> extract_context()

    %StatementBundle{
      body: events |> Oli.Analytics.Common.to_jsonlines(),
      bundle_id: context.bundle_id,
      partition_id: context.section_id,
      category: category,
      # TODO, we will want to detect the partition once we start
      partition: :section
      # emitting from the authoring side
    }
    |> emit()
  end

  def emit(category, event), do: emit(category, [event])

  defp extract_context(event) do
    section_id = event["context"]["extensions"]["http://oli.cmu.edu/extensions/section_id"]

    guid =
      Map.get(
        event["context"]["extensions"],
        "http://oli.cmu.edu/extensions/page_attempt_guid",
        UUID.uuid4()
      )

    bundle_id =
      :crypto.hash(:md5, guid <> "-" <> random_string(10))
      |> Base.encode16()

    %{section_id: section_id, bundle_id: bundle_id}
  end

  defp random_string(length) do
    Enum.reduce(1..length, [], fn _i, acc ->
      [Enum.random(@chars) | acc]
    end)
    |> Enum.join("")
  end
end
