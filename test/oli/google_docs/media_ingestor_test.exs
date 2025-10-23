defmodule Oli.GoogleDocs.MediaIngestorTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.GoogleDocs.MarkdownParser
  alias Oli.GoogleDocs.MediaIngestor
  alias Oli.GoogleDocs.MediaIngestor.{Entry, Result}
  alias Oli.GoogleDocsImport.TestHelpers

  defmodule StubMediaLibrary do
    @moduledoc false

    def reset do
      Process.delete({__MODULE__, :state})
      Process.delete({__MODULE__, :calls})
    end

    def call_count do
      Process.get({__MODULE__, :calls}, 0)
    end

    def add(project_slug, filename, contents) do
      hash = :crypto.hash(:sha256, contents)
      state_key = {__MODULE__, :state}
      calls_key = {__MODULE__, :calls}

      current_state = Process.get(state_key, %{})
      Process.put(calls_key, Process.get(calls_key, 0) + 1)

      case Map.get(current_state, hash) do
        nil ->
          url = "stub://#{project_slug}/#{filename}"
          media_item = %{url: url, file_name: filename}
          Process.put(state_key, Map.put(current_state, hash, media_item))
          {:ok, media_item}

        media_item ->
          {:duplicate, media_item}
      end
    end
  end

  defmodule FakeMediaLibrary do
    @moduledoc false
    def add(_slug, _filename, _binary), do: {:error, :persistence_failure}
  end

  describe "ingest/2" do
    test "uploads unique images and reuses duplicates within the same import" do
      project = insert(:project)
      StubMediaLibrary.reset()
      fixture = TestHelpers.load_fixture(:media)

      assert {:ok, parsed} =
               MarkdownParser.parse(fixture.body, metadata: fixture.metadata)

      media_refs = parsed.media
      assert length(media_refs) == 2

      assert {:ok, %Result{} = result} =
               MediaIngestor.ingest(media_refs,
                 project_slug: project.slug,
                 media_library: StubMediaLibrary
               )

      [first_id, second_id] = Enum.map(media_refs, & &1.id)

      assert %Entry{status: :uploaded, url: uploaded_url} = result.entries[first_id]

      assert %Entry{status: :reused, url: ^uploaded_url, source: :cache} =
               result.entries[second_id]

      assert result.order == [first_id, second_id]
      assert result.uploaded_count == 1
      assert result.reused_count == 1
      assert result.dedupe_hits == 1
      assert result.bytes_uploaded > 0
      assert result.skipped_count == 0
      assert result.failed_count == 0

      assert Enum.any?(result.warnings, &(&1.code == :media_dedupe_warning))
      assert StubMediaLibrary.call_count() == 1

      assert String.starts_with?(uploaded_url, "stub://#{project.slug}/")
    end

    test "skips oversized images and surfaces warnings" do
      project = insert(:project)
      StubMediaLibrary.reset()
      fixture = TestHelpers.load_fixture(:media)

      {:ok, parsed} = MarkdownParser.parse(fixture.body, metadata: fixture.metadata)

      assert {:ok, %Result{} = result} =
               MediaIngestor.ingest(parsed.media,
                 project_slug: project.slug,
                 max_bytes: 10,
                 media_library: StubMediaLibrary
               )

      assert result.uploaded_count == 0
      assert result.reused_count == 0
      assert result.skipped_count == 2
      assert result.failed_count == 0
      assert result.bytes_uploaded == 0

      assert Enum.all?(result.entries, fn {_id, %Entry{status: status}} ->
               status == :skipped_oversized
             end)

      assert Enum.all?(result.warnings, &(&1.code == :media_oversized))
      assert StubMediaLibrary.call_count() == 0
    end

    test "returns failure entries when uploads error" do
      project = insert(:project)
      fixture = TestHelpers.load_fixture(:media)

      {:ok, parsed} = MarkdownParser.parse(fixture.body, metadata: fixture.metadata)
      [first | _] = parsed.media

      assert {:ok, %Result{} = result} =
               MediaIngestor.ingest([first],
                 project_slug: project.slug,
                 media_library: FakeMediaLibrary
               )

      [only_id] = result.order

      assert %Entry{status: :failed, url: fallback, reason: :persistence_failure} =
               result.entries[only_id]

      assert fallback == first.src
      assert result.failed_count == 1
      assert result.uploaded_count == 0
      assert Enum.any?(result.warnings, &(&1.code == :media_upload_failed))
    end

    test "ignores remote images and leaves source URLs untouched" do
      project = insert(:project)

      remote =
        %Oli.GoogleDocs.MarkdownParser.MediaReference{
          id: "remote-1",
          src: "https://example.com/remote.png",
          alt: "Remote image",
          title: "Remote image",
          origin: :remote,
          mime_type: "image/png",
          data: nil,
          filename: nil,
          block_index: 0
        }

      assert {:ok, %Result{} = result} =
               MediaIngestor.ingest([remote],
                 project_slug: project.slug,
                 media_library: StubMediaLibrary
               )

      assert result.uploaded_count == 0
      assert result.reused_count == 0
      assert result.skipped_count == 1
      assert result.failed_count == 0
      assert result.warnings == []

      assert %Entry{status: :skipped_remote, url: "https://example.com/remote.png"} =
               result.entries["remote-1"]
    end
  end
end
