defmodule OliWeb.PageDeliveryControllerTest do
  use OliWeb.ConnCase

  import Mox

  alias Oli.Delivery.Sections
  alias Oli.Seeder
  alias Oli.Delivery.Attempts.{ResourceAttempt, PartAttempt, ResourceAccess}
  alias Lti_1p3.Tool.ContextRoles
  alias OliWeb.Router.Helpers, as: Routes

  describe "page_delivery_controller index" do
    setup [:setup_session]

    test "handles student access by an enrolled student", %{
      conn: conn,
      user: user,
      section: section
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        conn
        |> get(Routes.page_delivery_path(conn, :index, section.slug))

      assert html_response(conn, 200) =~ "Course Overview"
    end

    test "handles student page access by an enrolled student", %{
      conn: conn,
      revision: revision,
      user: user,
      section: section
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        conn
        |> get(Routes.page_delivery_path(conn, :page, section.slug, revision.slug))

      assert html_response(conn, 200) =~ "<h1 class=\"title\">"
    end

    test "handles student page access by a non enrolled student", %{
      conn: conn,
      revision: revision,
      section: section
    } do
      conn =
        conn
        |> get(Routes.page_delivery_path(conn, :page, section.slug, revision.slug))

      assert html_response(conn, 200) =~ "Not authorized"
    end

    test "handles student access who is not enrolled", %{conn: conn, section: section} do
      conn =
        conn
        |> get(Routes.page_delivery_path(conn, :index, section.slug))

      assert html_response(conn, 200) =~ "Not authorized"
    end

    test "shows the prologue page on an assessment", %{
      user: user,
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn = get(conn, Routes.page_delivery_path(conn, :page, section.slug, page_revision.slug))

      assert html_response(conn, 200) =~ "When you are ready to begin, you may"

      # now start the attempt
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn =
        get(
          conn,
          Routes.page_delivery_path(conn, :start_attempt, section.slug, page_revision.slug)
        )

      # verify the redirection
      assert html_response(conn, 302) =~ "redirected"
      redir_path = redirected_to(conn, 302)

      # and then the rendering of the page, which should contain a button
      # that says 'Submit Assessment'
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn = get(conn, redir_path)
      assert html_response(conn, 200) =~ "Submit Assessment"

      # fetch the resource attempt and part attempt that will have been created
      [attempt] = Oli.Repo.all(ResourceAttempt)
      [part_attempt] = Oli.Repo.all(PartAttempt)

      # simulate an interaction
      Oli.Delivery.Attempts.update_part_attempt(part_attempt, %{
        response: %{"input" => "a"}
      })

      # Submit the assessment and verify we see the summary view
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn =
        get(
          conn,
          Routes.page_delivery_path(
            conn,
            :finalize_attempt,
            section.slug,
            page_revision.slug,
            attempt.attempt_guid
          )
        )

      # fetch the resource id record and verify the grade rolled up
      [access] = Oli.Repo.all(ResourceAccess)
      assert access.score == 10
      assert access.out_of == 11

      # now visit the page again, verifying that we see the prologue, but this time it
      # does not allow us to start a new attempt
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn = get(conn, Routes.page_delivery_path(conn, :page, section.slug, page_revision.slug))

      assert html_response(conn, 200) =~ "You have 0 attempts remaining out of 1 total attempt"

      assert html_response(conn, 200) =~ "Attempt 1 of 1"

      # visit assessment review page
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn =
        get(
          conn,
          Routes.page_delivery_path(
            conn,
            :review_attempt,
            section.slug,
            page_revision.slug,
            attempt.attempt_guid
          )
        )

      assert html_response(conn, 200) =~ "(Review)"
    end

    test "changing a page from graded to ungraded allows the graded attempt to continue", %{
      map: map,
      project: project,
      user: user,
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn = get(conn, Routes.page_delivery_path(conn, :page, section.slug, page_revision.slug))

      assert html_response(conn, 200) =~ "When you are ready to begin, you may"

      # now start the graded attempt
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn =
        get(
          conn,
          Routes.page_delivery_path(conn, :start_attempt, section.slug, page_revision.slug)
        )

      # verify the redirection
      assert html_response(conn, 302) =~ "redirected"
      redir_path = redirected_to(conn, 302)

      # and then the rendering of the page, which should contain a button
      # that says 'Submit Assessment'
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn = get(conn, redir_path)
      assert html_response(conn, 200) =~ "Submit Assessment"

      # fetch the resource attempt and part attempt that will have been created
      [attempt] = Oli.Repo.all(ResourceAttempt)
      [part_attempt] = Oli.Repo.all(PartAttempt)

      # simulate an interaction
      Oli.Delivery.Attempts.update_part_attempt(part_attempt, %{
        response: %{"input" => "a"}
      })

      # Now change the page from graded to ungraded, and issue a publication
      toggle_graded = %{graded: false, title: "This is now ungraded"}

      Oli.Authoring.Editing.PageEditor.acquire_lock(
        project.slug,
        page_revision.slug,
        map.author.email
      )

      Oli.Authoring.Editing.PageEditor.edit(
        project.slug,
        page_revision.slug,
        map.author.email,
        toggle_graded
      )

      Oli.Authoring.Editing.PageEditor.release_lock(
        project.slug,
        page_revision.slug,
        map.author.email
      )

      Oli.Publishing.publish_project(project)

      # now visit the page again, verifying that we are able to resume the original graded attempt
      # even through the page has been changed to ungraded
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn = get(conn, Routes.page_delivery_path(conn, :page, section.slug, page_revision.slug))
      assert html_response(conn, 200) =~ "Submit Assessment"

      # Submit the assessment
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn =
        get(
          conn,
          Routes.page_delivery_path(
            conn,
            :finalize_attempt,
            section.slug,
            page_revision.slug,
            attempt.attempt_guid
          )
        )

      # now visit the page again, verifying that we see the page as an ungraded page
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn = get(conn, Routes.page_delivery_path(conn, :page, section.slug, page_revision.slug))
      assert html_response(conn, 200) =~ "This is now ungraded"
      refute html_response(conn, 200) =~ "Submit Assessment"
    end

    test "changing a page from ungraded to graded shows the prologue even with an ungraded attempt present",
         %{
           map: map,
           project: project,
           user: user,
           conn: conn,
           section: section,
           page_revision: page_revision
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      # Change the page to ungraded, and issue a publication
      toggle_graded = %{graded: false, title: "This is now ungraded"}

      Oli.Authoring.Editing.PageEditor.acquire_lock(
        project.slug,
        page_revision.slug,
        map.author.email
      )

      Oli.Authoring.Editing.PageEditor.edit(
        project.slug,
        page_revision.slug,
        map.author.email,
        toggle_graded
      )

      Oli.Authoring.Editing.PageEditor.release_lock(
        project.slug,
        page_revision.slug,
        map.author.email
      )

      Oli.Publishing.publish_project(project)

      # Visit the page in its ungraded state, thus generating a resource attempt
      conn = get(conn, Routes.page_delivery_path(conn, :page, section.slug, page_revision.slug))
      assert html_response(conn, 200) =~ "This is now ungraded"
      refute html_response(conn, 200) =~ "Submit Assessment"

      # Now change the page to graded and issue a publication
      toggle_graded = %{graded: true, title: "This is now graded"}

      Oli.Authoring.Editing.PageEditor.acquire_lock(
        project.slug,
        page_revision.slug,
        map.author.email
      )

      Oli.Authoring.Editing.PageEditor.edit(
        project.slug,
        page_revision.slug,
        map.author.email,
        toggle_graded
      )

      Oli.Authoring.Editing.PageEditor.release_lock(
        project.slug,
        page_revision.slug,
        map.author.email
      )

      Oli.Publishing.publish_project(project)

      # Now visit the page again, verifying that we are presented with the prologue page
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn = get(conn, Routes.page_delivery_path(conn, :page, section.slug, page_revision.slug))
      assert html_response(conn, 200) =~ "When you are ready to begin, you may"

      # now start the graded attempt
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn =
        get(
          conn,
          Routes.page_delivery_path(conn, :start_attempt, section.slug, page_revision.slug)
        )

      # verify the redirection
      assert html_response(conn, 302) =~ "redirected"
      redir_path = redirected_to(conn, 302)

      # and then the rendering of the page, which should contain a button
      # that says 'Submit Assessment'
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn = get(conn, redir_path)
      assert html_response(conn, 200) =~ "Submit Assessment"
    end
  end

  describe "open and free page_delivery_controller" do
    setup [:setup_open_and_free_section]

    test "handles new open and free user access", %{conn: conn, section: section} do
      Oli.Test.MockHTTP
      |> expect(:post, fn "https://www.google.com/recaptcha/api/siteverify",
                          _body,
                          _headers,
                          _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "success" => true
             })
         }}
      end)

      conn =
        conn
        |> get(Routes.page_delivery_path(conn, :index, section.slug))

      # redirected to enroll page
      assert html_response(conn, 302) =~ Routes.delivery_path(conn, :enroll, section.slug)

      conn =
        recycle(conn)
        |> post(Routes.delivery_path(conn, :create_user, section.slug), %{
          "user_details" => %{
            "redirect_to" => "/sections/some_title"
          },
          "g-recaptcha-response" => "some-valid-capcha-data"
        })

      assert html_response(conn, 302) =~ Routes.page_delivery_path(conn, :index, section.slug)
      user = Pow.Plug.current_user(conn)

      # make the same request with a user logged in
      conn =
        recycle(conn)
        |> get(Routes.page_delivery_path(conn, :index, section.slug))

      assert html_response(conn, 200) =~ "Course Overview"
      assert user.sub != nil

      # access again, verify the same user is used that was created before
      conn = recycle(conn)

      conn =
        conn
        |> get(Routes.page_delivery_path(conn, :index, section.slug))

      same_user = Pow.Plug.current_user(conn)

      assert html_response(conn, 200) =~ "Course Overview"
      assert user.id == same_user.id
      assert user.sub == same_user.sub
    end

    test "handles open and free user access when registration is closed", %{
      conn: conn,
      section: section
    } do
      enrolled_user = user_fixture()
      other_user = user_fixture()

      {:ok, _enrollment} =
        Sections.enroll(enrolled_user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        Plug.Test.init_test_session(conn, lti_session: nil)
        |> Pow.Plug.assign_current_user(other_user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      {:ok, section} = Sections.update_section(section, %{registration_open: false})

      conn = get(conn, Routes.page_delivery_path(conn, :index, section.slug))

      assert html_response(conn, 403) =~ "Section Not Available"

      # user that was previously enrolled should still be able to access
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(
          enrolled_user,
          OliWeb.Pow.PowHelpers.get_pow_config(:user)
        )

      conn = get(conn, Routes.page_delivery_path(conn, :index, section.slug))

      assert html_response(conn, 200) =~ "Course Overview"
    end

    test "handles open and free user access when date is before start date", %{
      conn: conn,
      section: section
    } do
      enrolled_user = user_fixture()
      other_user = user_fixture()

      {:ok, _enrollment} =
        Sections.enroll(enrolled_user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        Plug.Test.init_test_session(conn, lti_session: nil)
        |> Pow.Plug.assign_current_user(other_user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      {:ok, section} =
        Sections.update_section(section, %{
          start_date: Timex.now() |> Timex.add(Timex.Duration.from_days(1))
        })

      conn = get(conn, Routes.page_delivery_path(conn, :index, section.slug))

      assert html_response(conn, 403) =~ "Section Has Not Started"

      # user that was previously enrolled should still be able to access
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(
          enrolled_user,
          OliWeb.Pow.PowHelpers.get_pow_config(:user)
        )

      conn = get(conn, Routes.page_delivery_path(conn, :index, section.slug))

      assert html_response(conn, 200) =~ "Course Overview"
    end

    test "handles open and free user access when date is after end date", %{
      conn: conn,
      section: section
    } do
      enrolled_user = user_fixture()
      other_user = user_fixture()

      {:ok, _enrollment} =
        Sections.enroll(enrolled_user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        Plug.Test.init_test_session(conn, lti_session: nil)
        |> Pow.Plug.assign_current_user(other_user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      {:ok, section} =
        Sections.update_section(section, %{
          end_date: Timex.now() |> Timex.subtract(Timex.Duration.from_days(1))
        })

      conn = get(conn, Routes.page_delivery_path(conn, :index, section.slug))

      assert html_response(conn, 403) =~ "Section Has Concluded"

      # user that was previously enrolled should still be able to access
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(
          enrolled_user,
          OliWeb.Pow.PowHelpers.get_pow_config(:user)
        )

      conn = get(conn, Routes.page_delivery_path(conn, :index, section.slug))

      assert html_response(conn, 200) =~ "Course Overview"
    end
  end

  defp setup_session(%{conn: conn}) do
    user = user_fixture()

    content = %{
      "stem" => "1",
      "authoring" => %{
        "parts" => [
          %{
            "id" => "1",
            "responses" => [
              %{
                "rule" => "input like {a}",
                "score" => 10,
                "id" => "r1",
                "feedback" => %{"id" => "1", "content" => "yes"}
              },
              %{
                "rule" => "input like {b}",
                "score" => 11,
                "id" => "r2",
                "feedback" => %{"id" => "2", "content" => "almost"}
              },
              %{
                "rule" => "input like {c}",
                "score" => 0,
                "id" => "r3",
                "feedback" => %{"id" => "3", "content" => "no"}
              }
            ],
            "scoringStrategy" => "best",
            "evaluationStrategy" => "regex"
          }
        ]
      }
    }

    map =
      Seeder.base_project_with_resource2()
      |> Seeder.add_objective("objective one", :o1)
      |> Seeder.add_activity(
        %{title: "one", max_attempts: 2, content: content},
        :publication,
        :project,
        :author,
        :activity
      )

    attrs = %{
      graded: true,
      max_attempts: 1,
      title: "page1",
      content: %{
        "model" => [
          %{
            "type" => "activity-reference",
            "purpose" => "None",
            "activity_id" => Map.get(map, :activity).resource.id
          }
        ]
      },
      objectives: %{"attached" => [Map.get(map, :o1).resource.id]}
    }

    map = Seeder.add_page(map, attrs, :page)

    Seeder.attach_pages_to(
      [map.page1, map.page2, map.page.resource],
      map.container.resource,
      map.container.revision,
      map.publication
    )

    section =
      section_fixture(%{
        context_id: "some-context-id",
        project_id: map.project.id,
        publication_id: map.publication.id,
        institution_id: map.institution.id,
        open_and_free: false
      })

    lti_params =
      Oli.Lti_1p3.TestHelpers.all_default_claims()
      |> put_in(["https://purl.imsglobal.org/spec/lti/claim/context", "id"], section.slug)

    cache_lti_params("params-key", lti_params)

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
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
     page_revision: map.page.revision}
  end

  defp setup_open_and_free_section(_) do
    author = author_fixture()

    %{project: project, institution: institution} = Oli.Seeder.base_project_with_resource(author)

    {:ok, publication} = Oli.Publishing.publish_project(project)

    section =
      section_fixture(%{
        institution_id: institution.id,
        project_id: project.id,
        publication_id: publication.id,
        context_id: UUID.uuid4(),
        open_and_free: true,
        registration_open: true
      })

    %{section: section, project: project, publication: publication}
  end
end
