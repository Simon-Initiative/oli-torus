defmodule Oli.Plugs.MaybeGatedResourceTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Gating
  alias Oli.Seeder
  alias Oli.Delivery.Attempts.Core
  alias Lti_1p3.Tool.ContextRoles

  def insert_resource_attempt(resource_access, revision_id, attrs) do
    Core.create_resource_attempt(
      Map.merge(
        %{
          attempt_guid: UUID.uuid4(),
          attempt_number: 1,
          content: %{},
          resource_access_id: resource_access.id,
          revision_id: revision_id
        },
        attrs
      )
    )
  end

  describe "maybe_gated_resource plug" do
    setup [:setup_session]

    test "allows section overview access for student", %{
      conn: conn,
      user: user,
      section: section
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      ensure_user_visit(user, section)
      stub_current_time(~U[2023-11-04 20:00:00Z])

      conn =
        conn
        |> get(~p"/sections/#{section.slug}")

      assert html_response(conn, 200) =~ section.title
    end

    test "allows access to gated resource with an open gating condition", %{
      conn: conn,
      revision: revision,
      user: user,
      section: section
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      ensure_user_visit(user, section)

      _gating_condition =
        gating_condition_fixture(%{
          section_id: section.id,
          resource_id: revision.resource_id,
          data: %{start_datetime: yesterday(), end_datetime: tomorrow()}
        })

      {:ok, section} = Gating.update_resource_gating_index(section)
      {:ok, view, _html} = live(conn, "/sections/#{section.slug}/lesson/#{revision.slug}")
      ensure_content_is_visible(view)

      assert render(view) =~ "Page one"
    end

    test "blocks access to gated resource with a closed gating condition", %{
      conn: conn,
      revision: revision,
      user: user,
      section: section
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      _gating_condition =
        gating_condition_fixture(%{
          section_id: section.id,
          resource_id: revision.resource_id,
          data: %{end_datetime: yesterday()}
        })

      {:ok, section} = Gating.update_resource_gating_index(section)

      conn =
        conn
        |> get(~p"/sections/#{section.slug}/lesson/#{revision.slug}")

      assert html_response(conn, 403) =~
               "You are trying to access a resource that is gated by the following condition"

      assert html_response(conn, 403) =~
               "#{revision.title} is scheduled to end"
    end

    test "blocks access to gated graded resource when :allows_nothing is in a closed gating condition",
         %{
           conn: conn,
           revision: revision,
           user: user,
           section: section
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      Oli.Resources.update_revision(revision, %{graded: true})

      _gating_condition =
        gating_condition_fixture(%{
          graded_resource_policy: :allows_nothing,
          section_id: section.id,
          resource_id: revision.resource_id,
          data: %{end_datetime: yesterday()}
        })

      {:ok, section} = Gating.update_resource_gating_index(section)

      # since this graded page has no attempts, the user will be first redirected to the prologue page
      # from ~p"/sections/#{section.slug}/lesson/#{revision.slug}" to ~p"/sections/#{section.slug}/prologue/#{revision.slug}"
      # and then the maybe_gated_resource plug will block access to the graded page

      conn =
        conn
        |> get(~p"/sections/#{section.slug}/prologue/#{revision.slug}")

      assert html_response(conn, 403) =~
               "You are trying to access a resource that is gated by the following condition"

      assert html_response(conn, 403) =~
               "#{revision.title} is scheduled to end"
    end

    test "blocks access to gated graded resource with :allows_nothing policy and attempts present",
         %{
           conn: conn,
           revision: revision,
           user: user,
           section: section
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      Oli.Resources.update_revision(revision, %{graded: true})

      ra = Core.track_access(revision.resource_id, section.id, user.id)
      Core.update_resource_access(ra, %{score: 5, out_of: 10})

      insert_resource_attempt(ra, revision.id, %{
        date_evaluated: DateTime.utc_now(),
        score: 5,
        out_of: 10
      })

      _gating_condition =
        gating_condition_fixture(%{
          graded_resource_policy: :allows_nothing,
          section_id: section.id,
          resource_id: revision.resource_id,
          data: %{end_datetime: yesterday()}
        })

      {:ok, section} = Gating.update_resource_gating_index(section)

      conn =
        conn
        |> get(~p"/sections/#{section.slug}/lesson/#{revision.slug}")

      assert html_response(conn, 403) =~
               "You are trying to access a resource that is gated by the following condition"

      assert html_response(conn, 403) =~
               "#{revision.title} is scheduled to end"
    end

    test "blocks access to gated graded resource with :allows_review policy and no attempts present",
         %{
           conn: conn,
           revision: revision,
           user: user,
           section: section
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      Oli.Resources.update_revision(revision, %{graded: true})

      _gating_condition =
        gating_condition_fixture(%{
          graded_resource_policy: :allows_review,
          section_id: section.id,
          resource_id: revision.resource_id,
          data: %{end_datetime: yesterday()}
        })

      {:ok, section} = Gating.update_resource_gating_index(section)

      # since this graded page has no attempts, the user will be first redirected to the prologue page
      # from ~p"/sections/#{section.slug}/lesson/#{revision.slug}" to ~p"/sections/#{section.slug}/prologue/#{revision.slug}"
      # and then the maybe_gated_resource plug will block access to the graded page

      conn =
        conn
        |> get(~p"/sections/#{section.slug}/prologue/#{revision.slug}")

      assert html_response(conn, 403) =~
               "You are trying to access a resource that is gated by the following condition"

      assert html_response(conn, 403) =~
               "#{revision.title} is scheduled to end"
    end

    test "allows review with :allows_review policy and attempts present",
         %{
           conn: conn,
           revision: revision,
           user: user,
           section: section
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      Oli.Resources.update_revision(revision, %{graded: true})

      Sections.get_section_resource(section.id, revision.resource_id)
      |> Sections.update_section_resource(%{max_attempts: 2})

      ra = Core.track_access(revision.resource_id, section.id, user.id)
      Core.update_resource_access(ra, %{score: 5, out_of: 10})

      insert_resource_attempt(ra, revision.id, %{
        date_evaluated: DateTime.utc_now(),
        date_submitted: DateTime.utc_now(),
        lifecycle_state: :evaluated,
        score: 5,
        out_of: 10
      })

      _gating_condition =
        gating_condition_fixture(%{
          graded_resource_policy: :allows_review,
          section_id: section.id,
          resource_id: revision.resource_id,
          data: %{end_datetime: yesterday()}
        })

      {:ok, section} = Gating.update_resource_gating_index(section)

      {:ok, view, _html} = live(conn, "/sections/#{section.slug}/prologue/#{revision.slug}")

      assert render(view) =~ "Attempts 1/2"
    end

    test "allows student to resume an active attempt with :allows_review policy and active attempt present",
         %{
           conn: conn,
           revision: revision,
           user: user,
           section: section
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      Oli.Resources.update_revision(revision, %{
        graded: true,
        max_attempts: 2
      })

      ra = Core.track_access(revision.resource_id, section.id, user.id)

      insert_resource_attempt(ra, revision.id, %{
        content: %{"model" => []}
      })

      _gating_condition =
        gating_condition_fixture(%{
          graded_resource_policy: :allows_review,
          section_id: section.id,
          resource_id: revision.resource_id,
          data: %{end_datetime: yesterday()}
        })

      {:ok, section} = Gating.update_resource_gating_index(section)

      {:ok, view, _html} = live(conn, "/sections/#{section.slug}/lesson/#{revision.slug}")
      ensure_content_is_visible(view)
      assert render(view) =~ "Page one"
    end
  end

  defp ensure_content_is_visible(view) do
    # the content of the page will not be rendered until the socket is connected
    # and the client side confirms that the scripts are loaded
    view
    |> element("#eventIntercept")
    |> render_hook("survey_scripts_loaded", %{"loaded" => true})
  end

  defp setup_session(%{conn: conn}) do
    user = user_fixture()

    map = Seeder.base_project_with_resource4()

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> assign_current_user(user)

    {:ok,
     conn: conn,
     map: map,
     user: user,
     project: map.project,
     section: map.section_1,
     revision: map.revision1}
  end
end
