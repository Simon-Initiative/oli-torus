defmodule Oli.Interop.Ingest.Processor.MediaItems do
  alias Oli.Interop.Ingest.State

  def process(
        %State{
          project: %{id: project_id},
          media_manifest: %{"mediaItems" => media_items}
        } = state
      ) do
    State.notify_step_start(state, :media_items)

    payload =
      Enum.map(media_items, fn i ->
        %{
          url: i["url"],
          file_name: i["name"],
          mime_type: i["mimeType"],
          file_size: i["fileSize"],
          md5_hash: i["md5"],
          deleted: {:placeholder, :deleted},
          project_id: {:placeholder, :project_id},
          inserted_at: {:placeholder, :now},
          updated_at: {:placeholder, :now}
        }
      end)

    placeholders = %{
      now: DateTime.utc_now() |> DateTime.truncate(:second),
      project_id: project_id,
      deleted: false
    }

    Oli.Repo.insert_all(Oli.Authoring.MediaLibrary.MediaItem, payload, placeholders: placeholders)

    state
  end
end
