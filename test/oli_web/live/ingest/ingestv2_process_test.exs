defmodule OliWeb.Admin.IngestV2ProcessTest do
  # The LiveView processes the archive in tasks that share the test's database connection.
  use OliWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup [:admin_conn]

  setup %{admin: admin} do
    archive = "_digests/#{admin.id}-digest.zip"
    File.mkdir_p!(Path.dirname(archive))

    entries =
      for file <- Path.wildcard("test/oli/interop/digest/*.json") do
        {String.to_charlist(Path.basename(file)), File.read!(file)}
      end

    {:ok, _} = :zip.create(String.to_charlist(archive), entries)
    on_exit(fn -> File.rm(archive) end)

    :ok
  end

  test "an administrator's import records the imported project and its publication", %{
    conn: conn,
    admin: admin
  } do
    {:ok, view, _html} = live(conn, ~p"/admin/ingest/process")

    view |> element("button", "Preprocess") |> render_click()
    await(view, "button[phx-click='process']")

    view |> element("button[phx-click='process']") |> render_click()
    await(view, "h4", "Ingest succeeded")

    imported = assert_audited(:project_imported, actor: admin, source: :ui)
    assert imported.affected_author_id == admin.id

    # The import publishes the project, and publishes again for containers its products add.
    assert [_initial, _containers] =
             audit_events(:project_published,
               project_id: imported.project_id,
               actor: admin,
               source: :ui
             )
  end

  # The LiveView reports each step from a task, so its page changes after the click returns.
  defp await(view, selector, text \\ nil, attempts \\ 100)

  defp await(view, selector, text, 0) do
    flunk("#{selector} #{text} never rendered:\n#{render(view)}")
  end

  defp await(view, selector, text, attempts) do
    case has_element?(view, selector, text) do
      true ->
        :ok

      false ->
        Process.sleep(50)
        await(view, selector, text, attempts - 1)
    end
  end
end
