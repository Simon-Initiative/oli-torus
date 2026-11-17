defmodule OliWeb.Api.MediaControllerTest do
  use OliWeb.ConnCase

  alias Oli.Authoring.MediaLibrary

  test "deleting media items records each deleted item for the author", %{conn: conn} do
    %{author: author, project: project} = Oli.Seeder.base_project_with_resource2()

    {:ok, item} =
      MediaLibrary.create_media_item(%{
        project_id: project.id,
        url: "https://example.com/photo.png",
        file_name: "photo.png",
        mime_type: "image/png",
        file_size: 10,
        md5_hash: "photo-hash",
        deleted: false
      })

    conn =
      conn
      |> log_in_author(author)
      |> post("/api/v1/media/project/#{project.slug}/delete", %{"mediaItemIds" => [item.id]})

    assert %{"type" => "success", "count" => 1} = json_response(conn, 200)

    event =
      assert_audited(:media_deleted, project_id: project.id, actor: author, source: :api)

    assert event.entity_id == to_string(item.id)
    assert event.details == %{"file_name" => "photo.png", "mime_type" => "image/png"}
  end
end
