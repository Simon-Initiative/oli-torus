defmodule OliWeb.Api.BibEntryControllerTest do
  use OliWeb.ConnCase

  alias Oli.Authoring.Editing.BibEntryEditor
  alias Oli.Publishing.AuthoringResolver

  test "deleting an entry records the removal for the author", %{conn: conn} do
    %{author: author, project: project} = Oli.Seeder.base_project_with_resource2()

    {:ok, {:ok, entry}} =
      BibEntryEditor.create(project.slug, author, %{
        title: "A reference",
        content: %{"data" => []},
        author_id: author.id
      })

    conn =
      conn
      |> log_in_author(author)
      |> delete("/api/v1/bibs/project/#{project.slug}/entry/#{entry.resource_id}")

    assert %{"result" => "success"} = json_response(conn, 200)
    assert AuthoringResolver.from_resource_id(project.slug, entry.resource_id).deleted

    event =
      assert_audited(:authoring_content_removed,
        project_id: project.id,
        actor: author,
        source: :api
      )

    assert event.resource_id == entry.resource_id
    assert event.entity_snapshot["title"] == "A reference"
  end
end
