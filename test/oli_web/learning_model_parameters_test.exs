defmodule OliWeb.LearningModelParametersTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Oli.Accounts.SystemRole
  alias Oli.Authoring.Editing.ResourceEditor
  alias Oli.Resources.ResourceType

  @moduletag capture_log: true

  setup do
    seed = Oli.Seeder.base_project_with_resource2()
    admin = author_fixture(%{system_role_id: SystemRole.role_id().content_admin})

    {:ok, objective} =
      ResourceEditor.create(seed.project.slug, admin, ResourceType.id_for_objective(), %{
        title: "Objective"
      })

    {:ok, Map.merge(seed, %{admin: admin, objective: objective})}
  end

  test "admin downloads and uploads CSV through the project page", s do
    conn = log_in_author(s.conn, s.admin)
    download = get(conn, "/learning_model_parameters/#{s.project.slug}/download")
    assert download.status == 200
    assert get_resp_header(download, "content-type") == ["text/csv; charset=utf-8"]

    assert get_resp_header(download, "content-disposition") == [
             "attachment; filename=learning-model-parameters.csv"
           ]

    assert download.resp_body =~ "Objective"
    {:ok, view, html} = live(conn, path(s.project))
    assert html =~ "Generate and Download"
    assert has_element?(view, "input[type=file][data-phx-auto-upload]")
    assert has_element?(view, "#parameter-upload button[type=submit][disabled]")
    csv = "\uFEFF" <> String.replace(download.resp_body, ",0.0,", ",1.5,")

    upload =
      file_input(view, "#parameter-upload", :csv, [
        %{
          name: "parameters.csv",
          content: csv,
          type: "text/csv"
        }
      ])

    render_upload(upload, "parameters.csv", 50)

    assert has_element?(
             view,
             "progress[value='50'][max='100'][aria-label='Upload progress for parameters.csv']"
           )

    assert has_element?(view, "#parameter-upload button[type=submit][disabled]")
    assert render_click(view, "upload") =~ "wait for the upload to finish"

    render_upload(upload, "parameters.csv", 50)

    assert has_element?(
             view,
             "progress[value='100'][max='100'][aria-label='Upload progress for parameters.csv']"
           )

    assert has_element?(view, "#parameter-upload button[type=submit]:not([disabled])")

    assert Oli.Publishing.AuthoringResolver.from_resource_id(
             s.project.slug,
             s.objective.resource_id
           ).id == s.objective.id

    assert view |> form("#parameter-upload") |> render_submit() =~ "Importing parameters"
    assert render_async(view) =~ "Updated 1 resources"
    refute has_element?(view, "[role=status]", "Importing parameters")
    refute has_element?(view, "input[type=file][disabled]")
    refute has_element?(view, "button", "Remove")

    revision =
      Oli.Publishing.AuthoringResolver.from_resource_id(s.project.slug, s.objective.resource_id)

    assert revision.learning_model_parameters.payload.beta_lo == 1.5
    assert revision.previous_revision_id == s.objective.id
  end

  test "ordinary author cannot mount or download", s do
    conn = log_in_author(s.conn, s.author)
    assert {:error, {:redirect, _}} = live(conn, path(s.project))
    conn = get(conn, "/learning_model_parameters/#{s.project.slug}/download")
    assert conn.status in [302, 403]
  end

  test "anonymous requests require login", s do
    assert get(s.conn, path(s.project)).status == 302
    assert get(s.conn, "/learning_model_parameters/#{s.project.slug}/download").status == 302
  end

  test "upload validation errors are shown without editing the resource", s do
    {:ok, view, _} = live(log_in_author(s.conn, s.admin), path(s.project))

    upload =
      file_input(view, "#parameter-upload", :csv, [
        %{name: "bad.csv", content: "bad,headers\n", type: "text/csv"}
      ])

    render_upload(upload, "bad.csv")
    view |> form("#parameter-upload") |> render_submit()
    assert render_async(view) =~ "Row 1"
    refute has_element?(view, "input[type=file][disabled]")

    revision =
      Oli.Publishing.AuthoringResolver.from_resource_id(s.project.slug, s.objective.resource_id)

    assert revision.id == s.objective.id
  end

  test "overview link is visible only to content administrators", s do
    for {author, visible?} <- [{s.admin, true}, {s.author, false}] do
      {:ok, view, _} =
        live(
          log_in_author(s.conn, author),
          "/workspaces/course_author/#{s.project.slug}/overview"
        )

      assert has_element?(view, "a[href='#{path(s.project)}']") == visible?
    end
  end

  test "invalid file type is rejected", s do
    {:ok, view, _} = live(log_in_author(s.conn, s.admin), path(s.project))

    upload =
      file_input(view, "#parameter-upload", :csv, [
        %{name: "bad.txt", content: "bad", type: "text/plain"}
      ])

    assert {:error, _} = render_upload(upload, "bad.txt")
    assert render(view) =~ "Select a .csv file."
  end

  test "LiveView remains responsive and rejects duplicate imports while the task runs", s do
    {:ok, view, _} = live(log_in_author(s.conn, s.admin), path(s.project))

    csv =
      "title,resource_id,children_ids,beta_lo,beta_difficulty\nObjective,#{s.objective.resource_id},[],1.5,\n"

    upload =
      file_input(view, "#parameter-upload", :csv, [
        %{name: "parameters.csv", content: csv, type: "text/csv"}
      ])

    render_upload(upload, "parameters.csv")

    parent = self()
    handler = {__MODULE__, make_ref()}

    :telemetry.attach(
      handler,
      [:oli, :repo, :query],
      fn _, _, metadata, _ ->
        case String.starts_with?(metadata.query, "SELECT") do
          true ->
            send(parent, {:import_waiting, self()})

            receive do
              :continue_import -> :ok
            after
              5_000 -> :ok
            end

          false ->
            :ok
        end
      end,
      nil
    )

    try do
      assert view |> form("#parameter-upload") |> render_submit() =~ "Importing parameters"
      assert_receive {:import_waiting, worker}, 5_000

      try do
        assert has_element?(view, "input[type=file][disabled]")
        assert render_click(view, "upload") =~ "Importing parameters"
        assert render_click(view, "cancel", %{"ref" => "ignored"}) =~ "Importing parameters"
        assert render_change(view, "validate", %{}) =~ "Importing parameters"
      after
        :telemetry.detach(handler)
        send(worker, :continue_import)
      end

      assert render_async(view) =~ "Updated 1 resources"
    after
      :telemetry.detach(handler)
    end
  end

  test "an async import crash clears loading state and releases the upload", s do
    Ecto.Adapters.SQL.query!(
      Oli.Repo,
      "UPDATE revisions SET learning_model_parameters = '{}'::jsonb WHERE id = $1",
      [s.objective.id]
    )

    {:ok, view, _} = live(log_in_author(s.conn, s.admin), path(s.project))

    csv =
      "title,resource_id,children_ids,beta_lo,beta_difficulty\nObjective,#{s.objective.resource_id},[],1.5,\n"

    upload =
      file_input(view, "#parameter-upload", :csv, [
        %{name: "parameters.csv", content: csv, type: "text/csv"}
      ])

    render_upload(upload, "parameters.csv")
    view |> form("#parameter-upload") |> render_submit()
    assert render_async(view) =~ "The import failed. Please try again."
    refute has_element?(view, "input[type=file][disabled]")
    refute has_element?(view, "[role=status]", "Importing parameters")
    refute has_element?(view, "button", "Remove")
  end

  test "export failure after headers are sent ends the response and logs the failure", s do
    # Simulate a bad persisted envelope that fails decoding during cursor iteration.
    Ecto.Adapters.SQL.query!(
      Oli.Repo,
      "UPDATE revisions SET learning_model_parameters = '{}'::jsonb WHERE id = $1",
      [s.objective.id]
    )

    conn = log_in_author(s.conn, s.admin)

    log =
      ExUnit.CaptureLog.capture_log(fn ->
        response = get(conn, "/learning_model_parameters/#{s.project.slug}/download")
        assert response.status == 200
        assert response.state == :chunked
      end)

    assert log =~ "Learning-model CSV export failed"
  end

  defp path(project), do: "/workspaces/course_author/#{project.slug}/learning_model_parameters"
end
