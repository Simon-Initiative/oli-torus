defmodule Oli.Analytics.EventEmitter do
  alias Oli.Analytics.XAPI
  alias Oli.Analytics.XAPI.StatementBundle

  @chars "abcdefghijklmnopqrstuvwxyz1234567890" |> String.split("", trim: true)

  def emit_page_viewed(event) do
    section_id = event["context"]["extensions"]["http://oli.cmu.edu/extensions/section_id"]
    guid = event["context"]["extensions"]["http://oli.cmu.edu/extensions/page_attempt_guid"]

    bundle_id =
      :crypto.hash(:md5, guid <> "-" <> random_string(10))
      |> Base.encode16()

    %StatementBundle{
      body: [event] |> Oli.Analytics.Common.to_jsonlines(),
      bundle_id: bundle_id,
      partition: :section,
      partition_id: section_id,
      category: :page_viewed
    }
    |> XAPI.emit()
  end

  def random_string(length) do
    Enum.reduce(1..length, [], fn _i, acc ->
      [Enum.random(@chars) | acc]
    end)
    |> Enum.join("")
  end
end
