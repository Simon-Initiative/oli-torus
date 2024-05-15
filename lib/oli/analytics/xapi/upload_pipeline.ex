defmodule Oli.Analytics.XAPI.UploadPipeline do
  use Broadway

  alias Broadway.Message
  alias Oli.Analytics.XAPI.StatementBundle

  def start_link(_opts) do

    config = Oli.Analytics.XAPI.PipelineConfig.get()

    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {config.producer_module, []},
        transformer: {__MODULE__, :transform, []}
      ],
      processors: [
        default: [concurrency: config.processor_concurrency]
      ],
      batchers: [
        default: [
          concurrency: config.batcher_concurrency,
          batch_size: config.batch_size,
          batch_timeout: config.batch_timeout
        ]
      ]
    )
  end

  def transform(event, _opts) do
    %Message{
      data: event,
      acknowledger: Broadway.NoopAcknowledger.init()
    }
  end

  # Set the batch key so that all messages going to the same
  # folder get handled in one batch
  def handle_message(_, %Message{data: data} = message, _) do
    batch_key = build_batch_key(data)
    Message.put_batch_key(message, batch_key)
  end

  # Leverage the fact that our batch of messages is going to
  # the same folder and collapse their contents into one singular
  # message, saving potentially many individual uploads. This is
  # the most important reason why we are using Broadway here, for the
  # built-in batching capabilities, where we can coalesce messages
  # into one bundle before uploading.
  def handle_batch(:default, messages, _batch_info, _context) do

    Oli.Analytics.XAPI.Utils.record_pipeline_stats(
      %{batch_size: Enum.count(messages)}
    )

    messages
    |> coalesce()
    |> upload()

    messages
  end

  # Combine the body content of all of messages into one statement bundle
  defp coalesce(messages) do

    combined_body = Enum.map(messages, fn m -> m.data.body end)
    |> Enum.join("\n")

    hd(messages).data
    |> Map.put(:body, combined_body)
  end

  # upload the bundle, if it fails we store it so it can be replayed later
  defp upload(bundle) do

    %{uploader_module: uploader_module} = Oli.Analytics.XAPI.PipelineConfig.get()

    case apply(uploader_module, :upload, [bundle]) do
      {:error, _} ->
        Oli.Analytics.XAPI.QueueProducer.persist([bundle], :failed)
      _ ->
        true
    end
  end

  defp build_batch_key(%StatementBundle{
    partition: partition,
    partition_id: partition_id,
    category: category
  }) do
    "#{partition}/#{partition_id}/#{category}"
  end
end
