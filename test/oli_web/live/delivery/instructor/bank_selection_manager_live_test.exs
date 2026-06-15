defmodule OliWeb.Delivery.Instructor.BankSelectionManagerLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Oli.Delivery.Sections
  alias Oli.Resources.Collaboration.CollabSpaceConfig
  alias Oli.Seeder
  alias OliWeb.Delivery.Instructor.PreviewRoutes

  describe "bank selection manager preview route" do
    setup [:setup_preview_section_with_selection]

    test "selection_path helper points to the preview-session live route", %{
      section: section,
      page_revision: page_revision
    } do
      assert PreviewRoutes.selection_path(section.slug, page_revision.slug, "selection-1") ==
               "/sections/#{section.slug}/preview/lesson/#{page_revision.slug}/selection/selection-1"
    end

    test "authorized preview users can open the selection manager route directly", %{
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      {:ok, _view, html} =
        live(conn, PreviewRoutes.selection_path(section.slug, page_revision.slug, "selection-1"))

      assert html =~ ~s|id="instructor-preview-header"|
      assert html =~ ~s|id="bank-selection-manager"|
      assert html =~ "Selection manager route initialized for selection"
      assert html =~ "selection-1"
    end

    test "invalid selection redirects safely back to lesson preview and preserves only safe navigation params",
         %{
           conn: conn,
           section: section,
           page_revision: page_revision
         } do
      {:error, {:redirect, %{to: path, flash: flash}}} =
        live(
          conn,
          PreviewRoutes.selection_path(section.slug, page_revision.slug, "missing-selection", %{
            "return_to" => "/sections/#{section.slug}/remix?from=curriculum",
            "request_path" => "https://example.com/bad"
          })
        )

      assert path ==
               PreviewRoutes.lesson_path(section.slug, page_revision.slug, %{
                 "return_to" => "/sections/#{section.slug}/remix?from=curriculum"
               })

      assert flash["error"] == "We couldn’t find that activity bank selection for this page."
    end

    test "learner access is redirected out of preview mode by the existing section-preview plug",
         %{
           section: section,
           page_revision: page_revision
         } do
      learner = user_fixture(%{independent_learner: false})

      enroll_user_to_section(learner, section, :context_learner)
      cache_lti_context(section, learner)

      conn = build_conn() |> log_in_user(learner)

      {:error, {:redirect, %{to: path}}} =
        live(conn, PreviewRoutes.selection_path(section.slug, page_revision.slug, "selection-1"))

      assert path ==
               "/sections/#{section.slug}/lesson/#{page_revision.slug}/selection/selection-1"
    end
  end

  defp setup_preview_section_with_selection(%{conn: conn}) do
    user = user_fixture(%{independent_learner: false})

    map =
      Seeder.base_project_with_resource2()
      |> Seeder.add_page(
        %{
          graded: true,
          title: "bank selection page",
          content: %{
            "model" => [
              %{
                "type" => "selection",
                "id" => "selection-1",
                "logic" => %{"conditions" => nil},
                "count" => 2
              }
            ]
          }
        },
        :container,
        :page
      )

    {:ok, publication} =
      Oli.Publishing.publish_project(map.project, "bank selection preview", map.author.id)

    map =
      map
      |> Map.merge(%{publication: publication})
      |> Seeder.create_section()
      |> Seeder.create_section_resources()

    page_section_resource = Sections.get_section_resource(map.section.id, map.page.resource.id)

    {:ok, _updated_section_resource} =
      Sections.update_section_resource(page_section_resource, %{
        collab_space_config: %CollabSpaceConfig{status: :enabled}
      })

    enroll_user_to_section(user, map.section, :context_instructor)
    cache_lti_context(map.section, user)

    {:ok,
     conn: log_in_user(conn, user),
     user: user,
     section: map.section,
     page_revision: map.page.revision}
  end

  defp cache_lti_context(section, user) do
    Oli.Lti.TestHelpers.all_default_claims()
    |> put_in(["https://purl.imsglobal.org/spec/lti/claim/context", "id"], section.context_id)
    |> cache_lti_params(user.id)
  end
end
