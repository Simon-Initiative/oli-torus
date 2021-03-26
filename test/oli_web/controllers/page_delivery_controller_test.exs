defmodule OliWeb.PageDeliveryControllerTest do
  use OliWeb.ConnCase
  alias Oli.Delivery.Sections
  alias Oli.Seeder
  alias Oli.Delivery.Attempts.{ResourceAttempt, PartAttempt, ResourceAccess}
  alias Lti_1p3.Tool.ContextRoles
  alias OliWeb.Common.LtiSession

  describe "page_delivery_controller index" do
    setup [:setup_session]

    test "handles student access by an enrolled student", %{conn: conn, user: user, section: section} do

      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn = conn
      |> get(Routes.page_delivery_path(conn, :index, section.slug))

      assert html_response(conn, 200) =~ "Course Overview"
    end

    test "handles student page access by an enrolled student", %{conn: conn, revision: revision, user: user, section: section} do

      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn = conn
      |> get(Routes.page_delivery_path(conn, :page, section.slug, revision.slug))

      assert html_response(conn, 200) =~ "<h1>"
    end


    test "handles student page access by a non enrolled student", %{conn: conn, revision: revision, section: section} do

      conn = conn
      |> get(Routes.page_delivery_path(conn, :page, section.slug, revision.slug))

      assert html_response(conn, 200) =~ "Not authorized"
    end

    test "handles student access who is not enrolled", %{conn: conn, section: section} do
      conn = conn
      |> get(Routes.page_delivery_path(conn, :index, section.slug))

      assert html_response(conn, 200) =~ "Not authorized"
    end

    test "shows the prologue page on an assessment", %{user: user, conn: conn, section: section, page_revision: page_revision} do

      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn = get(conn, Routes.page_delivery_path(conn, :page, section.slug, page_revision.slug))

      assert html_response(conn, 200) =~ "When you are ready to begin, you may"

      # now start the attempt
      conn = recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))
      conn = get(conn, Routes.page_delivery_path(conn, :start_attempt, section.slug, page_revision.slug))

      # verify the redirection
      assert html_response(conn, 302) =~ "redirected"
      redir_path = redirected_to(conn, 302)

      # and then the rendering of the page, which should contain a button
      # that says 'Submit Assessment'
      conn = recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))
      conn = get(conn, redir_path)
      assert html_response(conn, 200) =~  "Submit Assessment"

      # fetch the resource attempt and part attempt that will have been created
      [attempt] = Oli.Repo.all(ResourceAttempt)
      [part_attempt] = Oli.Repo.all(PartAttempt)

      # simulate an interaction
      Oli.Delivery.Attempts.update_part_attempt(part_attempt, %{
        response: %{"input" => "a"}
      })

      # Submit the assessment and verify we see the summary view
      conn = recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))
      conn = get(conn, Routes.page_delivery_path(conn, :finalize_attempt, section.slug, page_revision.slug, attempt.attempt_guid))

      # fetch the resource id record and verify the grade rolled up
      [access] = Oli.Repo.all(ResourceAccess)
      assert access.score == 10
      assert access.out_of == 11

      # now visit the page again, verifying that we see the prologue, but this time it
      # does not allow us to start a new attempt
      conn = recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))
      conn = get(conn, Routes.page_delivery_path(conn, :page, section.slug, page_revision.slug))

      assert html_response(conn, 200) =~ "You have 0 attempts remaining out of 1 total attempt"

      assert html_response(conn, 200) =~ "Attempt 1 of 1"

      # visit assessment review page
      conn = recycle(conn)
             |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))
      conn = get(conn, Routes.page_delivery_path(conn, :review_attempt, section.slug, page_revision.slug, attempt.attempt_guid))

      assert html_response(conn, 200) =~ "(Review)"

    end

  end

  defp setup_session(%{conn: conn}) do
    user = user_fixture()

    content = %{
      "stem" => "1",
      "authoring" => %{
        "parts" => [
          %{"id" => "1", "responses" => [
            %{"rule" => "input like {a}", "score" => 10, "id" => "r1", "feedback" => %{"id" => "1", "content" => "yes"}},
            %{"rule" => "input like {b}", "score" => 11, "id" => "r2", "feedback" => %{"id" => "2", "content" => "almost"}},
            %{"rule" => "input like {c}", "score" => 0, "id" => "r3", "feedback" => %{"id" => "3", "content" => "no"}}
          ], "scoringStrategy" => "best", "evaluationStrategy" => "regex"}
        ]
      }
    }

    map = Seeder.base_project_with_resource2()
    |> Seeder.add_objective("objective one", :o1)
    |> Seeder.add_activity(%{title: "one", max_attempts: 2, content: content}, :publication, :project, :author, :activity)

    attrs = %{
      graded: true,
      max_attempts: 1,
      title: "page1",
      content: %{
        "model" => [
          %{"type" => "activity-reference", "purpose" => "None", "activity_id" => Map.get(map, :activity).resource.id}
        ]
      },
      objectives: %{"attached" => [Map.get(map, :o1).resource.id]}
    }

    map = Seeder.add_page(map, attrs, :page)

    Seeder.attach_pages_to([map.page1, map.page2, map.page.resource], map.container.resource, map.container.revision, map.publication)

    section = section_fixture(%{
      context_id: "some-context-id",
      project_id: map.project.id,
      publication_id: map.publication.id,
      institution_id: map.institution.id,
      open_and_free: false
    })

    lti_params = Oli.Lti_1p3.TestHelpers.all_default_claims()
      |> put_in(["https://purl.imsglobal.org/spec/lti/claim/context", "id"], section.slug)

    cache_lti_params("params-key", lti_params)

    conn = Plug.Test.init_test_session(conn, lti_session: nil)
      |> LtiSession.put_section_params(section.slug, "params-key")
      |> Pow.Plug.assign_current_user(map.author, OliWeb.Pow.PowHelpers.get_pow_config(:author))
      |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

    {:ok,
      conn: conn,
      map: map,
      author: map.author,
      institution: map.institution,
      user: user,
      project: map.project,
      publication: map.publication,
      section: section,
      revision: map.revision1,
      page_revision: map.page.revision
    }
  end
end
