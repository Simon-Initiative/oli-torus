defmodule Oli.Analytics.XAPI.UploadPipeline do
  use Broadway

  alias Broadway.Message
  alias Oli.Analytics.XAPI.StatementBundle
  alias Oli.Analytics.XAPI.Utils
  alias Phoenix.PubSub

  import Oli.Timing

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

    batch_size = Enum.count(messages)
    Utils.record_pipeline_stats(%{batch_size: batch_size})

    messages
    |> coalesce()
    |> upload(batch_size)

    messages
  end

  # Combine the body content of all of messages into one statement bundle
  defp coalesce(messages) do
    combined_body =
      Enum.map(messages, fn m -> m.data.body end)
      |> Enum.join("\n")

    hd(messages).data
    |> Map.put(:body, combined_body)
  end

  # upload the bundle, if it fails we store it so it can be replayed later. Internally,
  # the ExAws library will retry the upload multiple times before giving up. In case of
  # this hard failure we spool the bundle to the DB so it can be replayed later - or
  # potentially manually uploaded in a worst case scenario.
  defp upload(bundle, batch_size) do
    %{uploader_module: uploader_module} = Oli.Analytics.XAPI.PipelineConfig.get()

    mark = mark()
    retval = fn ->
      apply(uploader_module, :upload, [bundle])
    end
    |> run()
    |> emit([:oli, :xapi, :pipeline, :upload], :duration)

    elapsed_time = elapsed(mark) / 1000 / 1000
    PubSub.broadcast(Oli.PubSub, "xapi_upload_pipeline_stats", {:stats, {batch_size, elapsed_time}})

    case retval do
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
