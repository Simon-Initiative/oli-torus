defmodule OliWeb.Import.CSVImportViewTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

  setup [:admin_conn]

  setup %{admin: admin} do
    seeded = Oli.Seeder.base_project_with_resource2()
    file = "_imports/#{admin.id}-import.csv"
    File.mkdir_p!("_imports")
    on_exit(fn -> File.rm(file) end)

    Map.put(seeded, :csv_file, file)
  end

  test "each changed row records its replacement as the administrator", %{
    conn: conn,
    admin: admin,
    project: project,
    revision1: revision1,
    csv_file: file
  } do
    File.write!(file, """
    type,title,slug,duration_minutes,poster_image,intro_video,intro_content
    Page,#{revision1.title},#{revision1.slug},25,,,
    Page,Missing,no-such-page,10,,,
    """)

    {:ok, view, _html} = live(conn, ~p"/admin/#{project.slug}/import/csv")

    assert await_finished(view) =~ "Row #2 - failure"

    event =
      assert_audited(:authoring_content_replaced,
        project_id: project.id,
        actor: admin,
        source: :ui
      )

    assert event.resource_id == revision1.resource_id
    assert event.details == %{"reason" => "metadata_csv"}
    assert event.changes["duration_minutes"]["after"] == 25
  end

  # The rows are processed by a task the view starts on mount; it reports each row and then
  # that it finished.
  defp await_finished(view, attempts \\ 100) do
    html = render(view)

    case {html =~ "Finished!", attempts} do
      {true, _} ->
        html

      {false, 0} ->
        flunk("the CSV import did not finish")

      {false, _} ->
        Process.sleep(20)
        await_finished(view, attempts - 1)
    end
  end
end
