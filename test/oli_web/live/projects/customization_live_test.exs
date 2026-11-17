defmodule OliWeb.Projects.CustomizationLiveTest do
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Oli.Authoring.Course

  test "saving project labels records the change for the author", %{conn: conn} do
    author = insert(:author)
    {:ok, %{project: project}} = create_project_fixture("Biology", author)

    {:ok, view, _html} =
      live_isolated(conn, OliWeb.Projects.CustomizationLive,
        session: %{"project_slug" => project.slug, "author_id" => author.id}
      )

    view
    |> element("form")
    |> render_submit(%{"unit" => "Chapter", "module" => "", "section" => "Lesson"})

    labels = Course.get_project!(project.id).customizations
    assert {labels.unit, labels.module, labels.section} == {"Chapter", "Module", "Lesson"}

    event =
      assert_audited(:project_settings_changed,
        project_id: project.id,
        actor: author,
        source: :ui
      )

    assert %{"operation" => "set", "before" => nil, "after" => %{"unit" => "Chapter"}} =
             event.changes["customizations"]
  end
end
