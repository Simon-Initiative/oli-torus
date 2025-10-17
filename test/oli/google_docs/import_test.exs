defmodule Oli.GoogleDocs.ImportTest do
  use Oli.DataCase, async: false

  import Oli.Factory
  import Ecto.Query

  alias Oli.GoogleDocs.Import
  alias Oli.GoogleDocs.MediaIngestor
  alias Oli.GoogleDocsImport.TestHelpers
  alias Oli.Resources.Revision
  alias Oli.Auditing.LogEvent
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Authoring.Course

  alias __MODULE__.StubClient
  alias __MODULE__.InlineMarkupClient
  alias __MODULE__.StubMediaLibrary
  alias __MODULE__.MediaFixtureClient
  alias __MODULE__.FailingMcqBuilder
  alias __MODULE__.FailingMediaLibrary
  alias __MODULE__.RedirectClient

  describe "import/4" do
    setup do
      original_config = Application.get_env(:oli, :google_docs_import, [])

      on_exit(fn ->
        Application.put_env(:oli, :google_docs_import, original_config)
        flush_guard_table()
      end)

      :ok
    end

    test "imports google doc with youtube and mcq custom elements" do
      author = insert(:author)

      {:ok, project_info} = Course.create_project("Docs Import Project", author)
      project = project_info.project
      container = AuthoringResolver.root_container(project.slug)

      StubMediaLibrary.reset()

      Application.put_env(:oli, :google_docs_import,
        client: StubClient,
        media_options: [media_library: StubMediaLibrary]
      )

      {:ok, revision, warnings} =
        Import.import(project.slug, container.slug, "1AbcCustomElementDoc", author)

      assert Enum.map(warnings, & &1.code) == []

      persisted = Repo.get!(Revision, revision.id)

      model =
        persisted.content["model"]
        |> List.wrap()

      all_nodes = collect_nodes(model)

      youtube = Enum.find(all_nodes, &(&1["type"] == "youtube"))
      assert youtube
      assert youtube["src"] == "nioGsCPUjx8"

      assert Enum.any?(model, fn
               %{"type" => "content", "children" => children} -> length(children) > 1
               _ -> false
             end)

      activity_reference = Enum.find(all_nodes, &(&1["type"] == "activity-reference"))

      assert activity_reference
      assert activity_reference["activity_id"]

      log_event =
        LogEvent
        |> order_by(desc: :inserted_at)
        |> limit(1)
        |> Repo.one()

      assert log_event.event_type == :google_doc_imported
      assert log_event.project_id == project.id

      file_hash =
        :crypto.hash(:sha256, "1AbcCustomElementDoc")
        |> Base.encode16(case: :lower)

      assert log_event.details["file_id_hash"] == file_hash
    end

    test "returns error when file guard is already in progress" do
      author = insert(:author)

      {:ok, project_info} = Course.create_project("Guarded Project", author)
      project = project_info.project
      container = AuthoringResolver.root_container(project.slug)

      file_id = "1GuardedDoc"
      file_hash = :crypto.hash(:sha256, file_id) |> Base.encode16(case: :lower)

      ensure_guard_table()
      :ets.insert(:google_docs_import_guard, {{:google_docs_import, project.slug, file_hash}, 0})

      Application.put_env(:oli, :google_docs_import, client: StubClient)

      assert {:error, :import_in_progress, []} ==
               Import.import(project.slug, container.slug, file_id, author)
    end

    test "falls back to table when MCQ builder fails" do
      author = insert(:author)

      {:ok, project_info} = Course.create_project("Fallback Project", author)
      project = project_info.project
      container = AuthoringResolver.root_container(project.slug)

      StubMediaLibrary.reset()

      Application.put_env(:oli, :google_docs_import,
        client: StubClient,
        media_options: [media_library: StubMediaLibrary],
        mcq_builder: FailingMcqBuilder
      )

      {:ok, revision, warnings} =
        Import.import(project.slug, container.slug, "1FallbackDoc", author)

      assert Enum.any?(warnings, &(&1.code == :mcq_activity_creation_failed))

      persisted = Repo.get!(Revision, revision.id)

      tables =
        persisted.content["model"]
        |> Enum.flat_map(&Map.get(&1, "children", []))
        |> Enum.filter(&(&1["type"] == "table"))

      assert Enum.any?(tables, fn table ->
               Enum.any?(table["children"], fn row ->
                 Enum.any?(row["children"], fn cell ->
                   Enum.any?(cell["children"], fn text -> text["text"] == "correct" end)
                 end)
               end)
             end)

      refute Enum.any?(
               persisted.content["model"],
               fn block ->
                 Enum.any?(block["children"], &(&1["type"] == "activity-reference"))
               end
             )
    end

    test "records media upload warnings and retains original URLs on failure" do
      author = insert(:author)

      {:ok, project_info} = Course.create_project("Media Project", author)
      project = project_info.project
      container = AuthoringResolver.root_container(project.slug)

      Application.put_env(:oli, :google_docs_import,
        client: MediaFixtureClient,
        media_ingestor: MediaIngestor,
        media_options: [project_slug: project.slug, media_library: FailingMediaLibrary]
      )

      {:ok, revision, warnings} =
        Import.import(project.slug, container.slug, "1MediaDoc", author)

      assert Enum.any?(warnings, &(&1.code == :media_upload_failed))

      persisted = Repo.get!(Revision, revision.id)

      images =
        persisted.content["model"]
        |> Enum.flat_map(&Map.get(&1, "children", []))
        |> Enum.filter(&(&1["type"] == "img"))

      assert Enum.all?(images, fn image ->
               String.starts_with?(image["src"], "data:image/png;base64")
             end)
    end

    test "preserves inline markup spacing across block types" do
      author = insert(:author)

      {:ok, project_info} = Course.create_project("Inline Markup Project", author)
      project = project_info.project
      container = AuthoringResolver.root_container(project.slug)

      Application.put_env(:oli, :google_docs_import, client: InlineMarkupClient)

      assert {:ok, revision, warnings} =
               Import.import(project.slug, container.slug, "1InlineMarkupDoc", author)

      assert warnings == []

      persisted = Repo.get!(Revision, revision.id)

      all_blocks =
        persisted.content["model"]
        |> Enum.flat_map(fn
          %{"type" => "content", "children" => children} -> children
          other -> [other]
        end)

      paragraph = Enum.find(all_blocks, &(&1["type"] == "p"))
      para_children = paragraph["children"]

      assert Enum.at(para_children, 0)["text"] == "This is "
      assert Enum.at(para_children, 1)["text"] == "some"
      assert Enum.at(para_children, 1)["strong"]
      assert Enum.at(para_children, 2)["text"] == " markup with "
      assert Enum.at(para_children, 3)["text"] == "gentle"
      assert Enum.at(para_children, 3)["em"]
      assert Enum.at(para_children, 4)["text"] == " emphasis and inline "

      inline_formula = Enum.at(para_children, 5)
      assert inline_formula["type"] == "formula_inline"
      assert inline_formula["src"] == "\\frac{2}{3}"
      assert inline_formula["subtype"] == "latex"
      assert inline_formula["children"] == [%{"text" => ""}]

      assert Enum.at(para_children, 6)["text"] == "."

      ul = Enum.find(all_blocks, &(&1["type"] == "ul"))
      li = hd(ul["children"])
      list_paragraph = hd(li["children"])
      list_children = list_paragraph["children"]
      assert Enum.at(list_children, 0)["text"] == "Mix "
      assert Enum.at(list_children, 1)["text"] == "inline"
      assert Enum.at(list_children, 1)["strong"]
      assert Enum.at(list_children, 2)["text"] == " styles easily and include "

      list_formula = Enum.at(list_children, 3)
      assert list_formula["type"] == "formula_inline"
      assert list_formula["src"] == "x_y"
      assert list_formula["subtype"] == "latex"
      assert list_formula["children"] == [%{"text" => ""}]

      assert Enum.at(list_children, 4)["text"] == " math."

      table = Enum.find(all_blocks, &(&1["type"] == "table"))
      [_header | rows] = table["children"]
      first_row = hd(rows)
      first_cell = hd(first_row["children"])
      cell_children = first_cell["children"]
      assert Enum.at(cell_children, 0)["text"] == "Table cell with "
      assert Enum.at(cell_children, 1)["text"] == "bold"
      assert Enum.at(cell_children, 1)["strong"]
      assert Enum.at(cell_children, 2)["text"] == " text and "

      cell_formula = Enum.at(cell_children, 3)
      assert cell_formula["type"] == "formula_inline"
      assert cell_formula["src"] == "E=mc^2"
      assert cell_formula["subtype"] == "latex"
      assert cell_formula["children"] == [%{"text" => ""}]

      assert Enum.at(cell_children, 4)["text"] == " inside"
    end

    test "surfaces redirect warning when Google Docs responds with redirect" do
      author = insert(:author)

      {:ok, project_info} = Course.create_project("Redirect Project", author)
      project = project_info.project
      container = AuthoringResolver.root_container(project.slug)

      Application.put_env(:oli, :google_docs_import, client: RedirectClient)

      assert {:error, {:http_redirect, 307, location}, warnings} =
               Import.import(project.slug, container.slug, "1RedirectDoc", author)

      assert location == "https://accounts.google.com"
      assert [%{code: :download_redirect}] = warnings
    end
  end

  defmodule StubClient do
    alias Oli.GoogleDocsImport.TestHelpers

    def fetch_markdown(file_id, _opts) do
      fixture = TestHelpers.load_fixture(:custom_elements)

      {:ok,
       %{
         body: fixture.body,
         bytes: byte_size(fixture.body),
         content_type: "text/markdown",
         headers: [{"content-type", "text/markdown"}],
         url: TestHelpers.markdown_export_url(file_id),
         file_id: file_id
       }}
    end
  end

  defmodule InlineMarkupClient do
    alias Oli.GoogleDocsImport.TestHelpers

    @inline_markdown """
    This is **some** markup with _gentle_ emphasis and inline \\( \\frac{2}{3} \\).

    - Mix **inline** styles easily and include \\(x_y\\) math.

    | Column |
    | --- |
    | Table cell with **bold** text and \\(E=mc^2\\) inside |
    """

    def fetch_markdown(file_id, _opts) do
      body = String.trim_leading(@inline_markdown)

      {:ok,
       %{
         body: body,
         bytes: byte_size(body),
         content_type: "text/markdown",
         headers: [{"content-type", "text/markdown"}],
         url: TestHelpers.markdown_export_url(file_id),
         file_id: file_id
       }}
    end
  end

  defmodule RedirectClient do
    def fetch_markdown(_file_id, _opts) do
      {:error, {:http_redirect, 307, "https://accounts.google.com"}}
    end
  end

  defmodule MediaFixtureClient do
    alias Oli.GoogleDocsImport.TestHelpers

    def fetch_markdown(file_id, _opts) do
      fixture = TestHelpers.load_fixture(:media)

      {:ok,
       %{
         body: fixture.body,
         bytes: byte_size(fixture.body),
         content_type: "text/markdown",
         headers: [{"content-type", "text/markdown"}],
         url: TestHelpers.markdown_export_url(file_id),
         file_id: file_id
       }}
    end
  end

  defmodule StubMediaLibrary do
    @moduledoc false

    def reset do
      Process.delete({__MODULE__, :state})
    end

    def add(project_slug, filename, contents) do
      state_key = {__MODULE__, :state}
      current = Process.get(state_key, %{})

      hash = :crypto.hash(:sha256, contents)

      response =
        Map.get_lazy(current, hash, fn ->
          %{url: "stub://#{project_slug}/#{filename}", file_name: filename}
        end)

      Process.put(state_key, Map.put(current, hash, response))

      case Map.has_key?(current, hash) do
        true -> {:duplicate, response}
        false -> {:ok, response}
      end
    end
  end

  defmodule FailingMcqBuilder do
    @moduledoc false
    alias Oli.GoogleDocs.CustomElements.Mcq
    alias Oli.GoogleDocs.Warnings

    def build(%Mcq{}, _opts) do
      {:error, :activity_creation_failed,
       [Warnings.build(:mcq_activity_creation_failed, %{reason: "stubbed failure"})]}
    end
  end

  defmodule FailingMediaLibrary do
    @moduledoc false
    def add(_slug, _filename, _binary), do: {:error, :persistence_failure}
  end

  defp collect_nodes(node) when is_map(node) do
    [node | collect_nodes(Map.get(node, "children", []))]
  end

  defp collect_nodes(nodes) when is_list(nodes) do
    Enum.flat_map(nodes, &collect_nodes/1)
  end

  defp collect_nodes(_), do: []

  defp ensure_guard_table do
    case :ets.info(:google_docs_import_guard) do
      :undefined ->
        :ets.new(:google_docs_import_guard, [:named_table, :set, :public, read_concurrency: true])

      _ ->
        :ok
    end
  end

  defp flush_guard_table do
    case :ets.info(:google_docs_import_guard) do
      :undefined -> :ok
      _ -> :ets.delete(:google_docs_import_guard)
    end
  end
end
