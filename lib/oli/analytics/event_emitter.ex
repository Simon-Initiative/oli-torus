defmodule Oli.Analytics.EventEmitter do

  @chars "abcdefghijklmnopqrstuvwxyz1234567890" |> String.split("", trim: true)

  def emit_page_viewed(event) do

    section_id = event["context"]["extensions"]["http://oli.cmu.edu/extensions/section_id"]
    guid = event["context"]["extensions"]["http://oli.cmu.edu/extensions/page_attempt_guid"]

    bundle_id = :crypto.hash(:md5, guid <> "-" <> random_string(10))
    |> Base.encode16()

    Oli.Delivery.Snapshots.S3UploaderWorker.new(%{
      body: [event] |> Oli.Analytics.Common.to_jsonlines(),
      bundle_id: bundle_id,
      partition_id: section_id,
      category: :page_viewed
    })
    |> Oban.insert()
  end

  def random_string(length) do
    Enum.reduce(1..length, [], fn _i, acc ->
      [Enum.random(@chars) | acc]
    end)
    |> Enum.join("")
  end

end
