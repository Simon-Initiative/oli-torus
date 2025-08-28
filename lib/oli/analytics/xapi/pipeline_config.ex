defmodule Oli.Analytics.XAPI.PipelineConfig do
  @keys [
    :producer_module,
    :uploader_module,
    :batcher_concurrency,
    :batch_size,
    :batch_timeout,
    :processor_concurrency
  ]

  def get() do
    config =
      case Application.fetch_env(:oli, :xapi_upload_pipeline) do
        {:ok, c} -> c
        _ -> []
      end

    defaults = defaults()

    Enum.reduce(@keys, %{}, fn key, acc ->
      Map.put(acc, key, Keyword.get(config, key, Keyword.get(defaults, key)))
    end)
  end

  def defaults() do
    get_env_as_integer = fn key, default ->
      System.get_env(key, default)
      |> String.to_integer()
    end

    [
      producer_module: Oli.Analytics.XAPI.QueueProducer,
      uploader_module: Oli.Analytics.XAPI.Uploader,
      batcher_concurrency: get_env_as_integer.("XAPI_BATCHER_CONCURRENCY", "20"),
      batch_size: get_env_as_integer.("XAPI_BATCH_SIZE", "50"),
      batch_timeout: get_env_as_integer.("XAPI_BATCH_TIMEOUT", "5000"),
      processor_concurrency: get_env_as_integer.("XAPI_PROCESSOR_CONCURRENCY", "2")
    ]
  end
end
