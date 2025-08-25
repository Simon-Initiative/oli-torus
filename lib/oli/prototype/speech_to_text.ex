defmodule Oli.Prototype.SpeechToText do
  use GenServer
  require Logger

  # ----------------
  # Client

  @spec start_link(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(init_args),
    do: GenServer.start_link(__MODULE__, init_args, name: __MODULE__)

  def transcribe(video_id, audio_filename),
    do: GenServer.call(__MODULE__, {:get, video_id, audio_filename}, :infinity)

  # ----------------
  # Server callbacks

  def init(_) do
    try do
      {:ok, model_info} = Bumblebee.load_model({:hf, "openai/whisper-small"})
      {:ok, featurizer} = Bumblebee.load_featurizer({:hf, "openai/whisper-small"})
      {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, "openai/whisper-small"})
      {:ok, generation_config} = Bumblebee.load_generation_config({:hf, "openai/whisper-small"})
      generation_config = Bumblebee.configure(generation_config, max_new_tokens: 100)

      serving =
        Bumblebee.Audio.speech_to_text_whisper(
          model_info,
          featurizer,
          tokenizer,
          generation_config,
          compile: [batch_size: 4],
          chunk_num_seconds: 30,
          timestamps: :segments,
          stream: true,
          defn_options: [compiler: EXLA]
        )

      Logger.info("Completed Speech to Text Initialization")

      {:ok, serving}
    rescue
      error ->
        Logger.error("Failed to initialize Speech to Text: #{inspect(error)}")
        {:stop, {:error, "Failed to initialize Whisper model"}}
    end
  end

  def handle_call({:get, video_id, filename}, from, serving) do
    # Start transcription in a separate task to avoid blocking the GenServer
    Task.start(fn ->
      transcribe_async(video_id, filename, serving, from)
    end)

    {:noreply, serving}
  end

  defp transcribe_async(video_id, filename, serving, from) do
    try do
      Logger.info("Starting Speech to Text for #{video_id}")

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      collected_values =
        for chunk <- Nx.Serving.run(serving, {:file, filename}) do
          [start_mark, end_mark] =
            for seconds <- [chunk.start_timestamp_seconds, chunk.end_timestamp_seconds],
                do: seconds |> round() |> Time.from_seconds_after_midnight()

          # Broadcast progress for LiveView updates
          Phoenix.PubSub.broadcast(
            Oli.PubSub,
            "prototype_transcription:#{video_id}",
            {:transcription_chunk, %{start: start_mark, end: end_mark, text: chunk.text}}
          )

          Logger.debug("Processed chunk for #{video_id}: start: #{start_mark}, end: #{end_mark}")

          %{
            video_id: video_id,
            start: start_mark,
            end: end_mark,
            text: chunk.text,
            inserted_at: now,
            updated_at: now
          }
        end

      result =
        case Enum.count(collected_values) do
          0 ->
            Logger.warning("Collected ZERO transcriptions for #{video_id}")
            {:error, "Collected ZERO transcriptions for #{video_id}"}

          n ->
            Logger.info("Collected #{n} transcriptions for #{video_id}")
            # For prototype, we'll just return the transcriptions instead of saving to DB
            {:ok, collected_values}
        end

      # Broadcast completion
      Phoenix.PubSub.broadcast(
        Oli.PubSub,
        "prototype_transcription:#{video_id}",
        {:transcription_complete, result}
      )

      GenServer.reply(from, result)
    rescue
      error ->
        Logger.error("Error during transcription: #{inspect(error)}")
        result = {:error, "Transcription failed: #{inspect(error)}"}

        Phoenix.PubSub.broadcast(
          Oli.PubSub,
          "prototype_transcription:#{video_id}",
          {:transcription_complete, result}
        )

        GenServer.reply(from, result)
    end
  end
end
