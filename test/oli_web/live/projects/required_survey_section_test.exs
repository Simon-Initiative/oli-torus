defmodule OliWeb.Projects.RequiredSurveySectionTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import LiveComponentTests
  import Oli.Factory

  alias Oli.Delivery.Sections.Audited
  alias Oli.Utils.Seeder
  alias OliWeb.Projects.RequiredSurvey

  setup do
    author = insert(:author)

    seeds =
      Seeder.Project.create_sample_project(%{}, author,
        project_tag: :project,
        publication_tag: :publication
      )

    survey = create_project_survey_fixture(seeds.project, author)
    Seeder.Project.ensure_published(seeds, seeds.publication)
    publication = Oli.Publishing.get_latest_published_publication_by_slug(seeds.project.slug)

    {:ok, section} =
      Audited.create_section_from_publication(
        audit_context(),
        publication,
        %{
          title: "Survey section",
          type: :enrollable,
          base_project_id: seeds.project.id,
          context_id: UUID.uuid4()
        },
        rebuild: true
      )

    %{section: section, survey: survey}
  end

  test "requiring the survey in a section records the change as the actor", %{
    conn: conn,
    section: section,
    survey: survey
  } do
    actor = insert(:user)

    {:ok, view, _html} =
      live_component_isolated(conn, RequiredSurvey, %{
        id: "section-required-survey",
        actor: actor,
        project: section,
        enabled: section.required_survey_resource_id,
        is_section: true
      })

    view |> element("form") |> render_change(%{"survey" => "on"})

    assert Oli.Delivery.Sections.get_section!(section.id).required_survey_resource_id ==
             survey.resource_id

    event =
      assert_audited(:section_settings_changed, section_id: section.id, actor: actor, source: :ui)

    assert event.changes["required_survey_resource_id"]["after"] == survey.resource_id
  end
end
