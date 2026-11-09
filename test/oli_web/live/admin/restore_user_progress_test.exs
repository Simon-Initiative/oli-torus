defmodule OliWeb.Admin.RestoreUserProgressTest do
  use OliWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Oli.Factory
  import Ecto.Query

  alias Oli.Repo
  alias OliWeb.Admin.RestoreUserProgress
  alias Oli.Delivery.Attempts.Core.{ResourceAccess, ResourceAttempt}

  @moduledoc false

  # - Verifies access control to the developer tool page
  # - Preview populates users and changes based on enrollments and accesses
  # - Commit applies changes: reassigns user_id or shifts scores/attempts

  @route Routes.live_path(OliWeb.Endpoint, RestoreUserProgress)

  describe "access control" do
    test "redirects to new session when accessing restore progress while not logged in", %{
      conn: conn
    } do
      assert {:error, {:redirect, %{to: "/authors/log_in"}}} = live(conn, @route)
    end

    test "redirects to authoring workspace when accessing restore progress as non-admin author",
         %{conn: conn} do
      author = insert(:author)
      conn = log_in_author(conn, author)
      assert {:error, {:redirect, %{to: "/workspaces/course_author"}}} = live(conn, @route)
    end
  end

  describe "verify_enrollments/3" do
    setup do
      section = insert(:section)
      target_user = insert(:user)
      source_user = insert(:user)

      target_enrollment = insert(:enrollment, user: target_user, section: section)
      source_enrollment = insert(:enrollment, user: source_user, section: section)

      %{
        section: section,
        target_user: target_user,
        source_user: source_user,
        target_enrollment: target_enrollment,
        source_enrollment: source_enrollment
      }
    end

    test "returns the section and both enrollments with users preloaded", ctx do
      assert {:ok, result} =
               RestoreUserProgress.verify_enrollments(
                 ctx.section.slug,
                 Integer.to_string(ctx.target_user.id),
                 Integer.to_string(ctx.source_user.id)
               )

      assert result.section.id == ctx.section.id
      assert result.target_enrollment.id == ctx.target_enrollment.id
      assert result.source_enrollment.id == ctx.source_enrollment.id
      assert result.target_enrollment.user.id == ctx.target_user.id
      assert result.source_enrollment.user.id == ctx.source_user.id
    end

    test "trims surrounding whitespace from the inputs", ctx do
      assert {:ok, _} =
               RestoreUserProgress.verify_enrollments(
                 " #{ctx.section.slug} ",
                 " #{ctx.target_user.id} ",
                 " #{ctx.source_user.id}\n"
               )
    end

    test "accepts enrollments that are not in the enrolled status", ctx do
      ctx.source_enrollment
      |> Ecto.Changeset.change(status: :suspended)
      |> Repo.update!()

      assert {:ok, %{source_enrollment: %{status: :suspended}}} =
               RestoreUserProgress.verify_enrollments(
                 ctx.section.slug,
                 Integer.to_string(ctx.target_user.id),
                 Integer.to_string(ctx.source_user.id)
               )
    end

    test "fails when the section slug is blank", ctx do
      assert {:error, "Set a section slug."} =
               RestoreUserProgress.verify_enrollments(
                 "  ",
                 Integer.to_string(ctx.target_user.id),
                 Integer.to_string(ctx.source_user.id)
               )
    end

    test "fails when a user id is not a positive integer", ctx do
      for invalid <- ["", "abc", "12abc", "0", "-3", nil] do
        assert {:error, "Set a valid target user ID."} =
                 RestoreUserProgress.verify_enrollments(
                   ctx.section.slug,
                   invalid,
                   Integer.to_string(ctx.source_user.id)
                 )

        assert {:error, "Set a valid source user ID."} =
                 RestoreUserProgress.verify_enrollments(
                   ctx.section.slug,
                   Integer.to_string(ctx.target_user.id),
                   invalid
                 )
      end
    end

    test "fails when target and source are the same user", ctx do
      user_id = Integer.to_string(ctx.target_user.id)

      assert {:error, "Target and source user IDs must be different."} =
               RestoreUserProgress.verify_enrollments(ctx.section.slug, user_id, user_id)
    end

    test "fails when the section does not exist", ctx do
      assert {:error, "Section missing_section not found."} =
               RestoreUserProgress.verify_enrollments(
                 "missing_section",
                 Integer.to_string(ctx.target_user.id),
                 Integer.to_string(ctx.source_user.id)
               )
    end

    test "fails when the target user is not enrolled in the section", ctx do
      outsider = insert(:user)

      expected =
        "Target user #{outsider.id} is not enrolled in section #{ctx.section.slug}."

      assert {:error, ^expected} =
               RestoreUserProgress.verify_enrollments(
                 ctx.section.slug,
                 Integer.to_string(outsider.id),
                 Integer.to_string(ctx.source_user.id)
               )
    end

    test "fails when the source user is only enrolled in a different section", ctx do
      outsider = insert(:user)
      insert(:enrollment, user: outsider, section: insert(:section))

      expected =
        "Source user #{outsider.id} is not enrolled in section #{ctx.section.slug}."

      assert {:error, ^expected} =
               RestoreUserProgress.verify_enrollments(
                 ctx.section.slug,
                 Integer.to_string(ctx.target_user.id),
                 Integer.to_string(outsider.id)
               )
    end
  end

  describe "preview and commit" do
    setup [:admin_conn]

    test "preview lists users and proposed changes for practice pages where true user has no access",
         %{conn: conn} do
      # Arrange: create users and a section; enroll both, but ensure independent_learner == false to be included
      institution_section = insert(:section)
      true_user = insert(:user, independent_learner: false, email: "u1@example.edu")
      other_user = insert(:user, independent_learner: false, email: "u1@example.edu")

      target_enrollment = insert(:enrollment, user: true_user, section: institution_section)
      source_enrollment = insert(:enrollment, user: other_user, section: institution_section)

      # Practice resource: graded? false
      resource = insert(:resource)

      # Access exists for other_user only
      other_access =
        insert(:resource_access,
          user: other_user,
          section: institution_section,
          resource: resource
        )

      {:ok, view, _} = live(conn, @route)

      verify(view, target_enrollment, source_enrollment)

      view |> element("#preview_button") |> render_click()

      assert has_element?(view, "#verified_target", Integer.to_string(true_user.id))
      assert has_element?(view, "#verified_source", Integer.to_string(other_user.id))

      # Expect a proposed change referencing the other_access id (reassign to true_user)
      assert has_element?(view, "#preview_changes", inspect(other_access.id))
    end

    test "commit reassigns resource access to the true user when preview proposes a single id move",
         %{conn: conn} do
      section = insert(:section)
      true_user = insert(:user, independent_learner: false, email: "shared@example.edu")
      other_user = insert(:user, independent_learner: false, email: "shared@example.edu")

      target_enrollment = insert(:enrollment, user: true_user, section: section)
      source_enrollment = insert(:enrollment, user: other_user, section: section)

      resource = insert(:resource)
      access = insert(:resource_access, user: other_user, section: section, resource: resource)

      {:ok, view, _} = live(conn, @route)

      verify(view, target_enrollment, source_enrollment)

      view |> element("#preview_button") |> render_click()
      view |> element("#commit_button") |> render_click()

      reloaded = Repo.get!(ResourceAccess, access.id)
      assert reloaded.user_id == true_user.id
    end

    test "commit shifts score and attempts when preview proposes a tuple {from, to}", %{
      conn: conn
    } do
      section = insert(:section)
      true_user = insert(:user, independent_learner: false, email: "shared2@example.edu")
      other_user = insert(:user, independent_learner: false, email: "shared2@example.edu")

      target_enrollment = insert(:enrollment, user: true_user, section: section)
      source_enrollment = insert(:enrollment, user: other_user, section: section)

      resource = insert(:resource)

      # Graded page scenario: ensure a graded revision for the shared resource so preview uses graded branch
      _graded_rev = insert(:revision, resource: resource, graded: true)

      # true user has access without score; other user has scored access
      access_to =
        insert(:resource_access,
          user: true_user,
          section: section,
          resource: resource,
          score: nil,
          out_of: nil
        )

      access_from =
        insert(:resource_access,
          user: other_user,
          section: section,
          resource: resource,
          score: 9.0,
          out_of: 10.0
        )

      attempt = insert(:resource_attempt, resource_access: access_from)

      {:ok, view, _} = live(conn, @route)

      verify(view, target_enrollment, source_enrollment)

      view |> element("#preview_button") |> render_click()
      view |> element("#commit_button") |> render_click()

      # Assert scores moved
      to_after = Repo.get!(ResourceAccess, access_to.id)
      _from_after = Repo.get!(ResourceAccess, access_from.id)
      assert to_after.score == 9.0
      assert to_after.out_of == 10.0

      # Assert resource attempts moved (only when target had none initially)
      attempts_for_to =
        Repo.all(from(ra in ResourceAttempt, where: ra.resource_access_id == ^access_to.id))

      assert Enum.any?(attempts_for_to, &(&1.id == attempt.id))

      attempts_for_from =
        Repo.all(from(ra in ResourceAttempt, where: ra.resource_access_id == ^access_from.id))

      assert attempts_for_from == []
    end
  end

  describe "verification step" do
    setup [:admin_conn]

    setup do
      section = insert(:section, title: "Chemistry 101")

      target_user =
        insert(:user, given_name: "Ada", family_name: "Target", email: "ada@example.edu")

      source_user =
        insert(:user, given_name: "Bob", family_name: "Source", email: "bob@example.edu")

      target_enrollment =
        insert(:enrollment,
          user: target_user,
          section: section,
          inserted_at: ~U[2026-01-15 14:30:00Z]
        )

      source_enrollment =
        insert(:enrollment, user: source_user, section: section, status: :suspended)

      %{
        section: section,
        target_user: target_user,
        source_user: source_user,
        target_enrollment: target_enrollment,
        source_enrollment: source_enrollment
      }
    end

    test "shows the details of both users once they are verified", ctx do
      {:ok, view, _} = live(ctx.conn, @route)

      html = verify(view, ctx.target_enrollment, ctx.source_enrollment)

      assert has_element?(view, "#verified_users", "Chemistry 101 (#{ctx.section.slug})")

      assert has_element?(view, "#verified_target", "Ada Target")
      assert has_element?(view, "#verified_target", "ada@example.edu")
      assert has_element?(view, "#verified_target", Integer.to_string(ctx.target_user.id))
      assert has_element?(view, "#verified_target", "January 15, 2026")
      assert has_element?(view, "#verified_target", "enrolled")

      assert has_element?(view, "#verified_source", "Bob Source")
      assert has_element?(view, "#verified_source", "bob@example.edu")
      assert has_element?(view, "#verified_source", "suspended")

      refute html =~ "not enrolled"
    end

    test "shows an error and no user details when verification fails", ctx do
      {:ok, view, _} = live(ctx.conn, @route)
      outsider = insert(:user)

      view
      |> form("#verify_form", %{
        "section_slug" => ctx.section.slug,
        "target_user_id" => Integer.to_string(ctx.target_user.id),
        "source_user_id" => Integer.to_string(outsider.id)
      })
      |> render_submit()

      assert has_element?(
               view,
               "#result",
               "Source user #{outsider.id} is not enrolled in section #{ctx.section.slug}."
             )

      refute has_element?(view, "#verified_users")
    end

    test "editing the form after verifying clears the verified users and preview", ctx do
      {:ok, view, _} = live(ctx.conn, @route)

      verify(view, ctx.target_enrollment, ctx.source_enrollment)
      view |> element("#preview_button") |> render_click()
      assert has_element?(view, "#verified_users")

      view
      |> form("#verify_form", %{"source_user_id" => "999999"})
      |> render_change()

      refute has_element?(view, "#verified_users")
      refute render(view) =~ "ada@example.edu"
    end

    test "preview requires a successful verification", ctx do
      {:ok, view, _} = live(ctx.conn, @route)

      assert has_element?(view, "#preview_button[disabled]")
      assert has_element?(view, "#commit_button[disabled]")

      render_click(view, "preview", %{})

      assert has_element?(view, "#result", "Verify the users before previewing changes.")
    end
  end

  describe "preview and commit gating" do
    setup [:admin_conn]

    setup do
      section = insert(:section)
      target_user = insert(:user)
      source_user = insert(:user)

      %{
        section: section,
        target_user: target_user,
        source_user: source_user,
        target_enrollment: insert(:enrollment, user: target_user, section: section),
        source_enrollment: insert(:enrollment, user: source_user, section: section)
      }
    end

    test "enables preview after verifying and commit only after a preview with changes", ctx do
      insert(:resource_access,
        user: ctx.source_user,
        section: ctx.section,
        resource: insert(:resource)
      )

      {:ok, view, _} = live(ctx.conn, @route)

      verify(view, ctx.target_enrollment, ctx.source_enrollment)

      refute has_element?(view, "#preview_button[disabled]")
      assert has_element?(view, "#commit_button[disabled]")

      view |> element("#preview_button") |> render_click()

      refute has_element?(view, "#commit_button[disabled]")

      view |> element("#commit_button") |> render_click()

      assert has_element?(view, "#result", "Success: 1 change(s) applied.")
      assert has_element?(view, "#commit_button[disabled]", "Done!")
      assert has_element?(view, "#preview_button[disabled]")

      render_click(view, "commit", %{})
      assert has_element?(view, "#result", "Changes have already been committed.")
    end

    test "keeps commit disabled when the preview has no changes", ctx do
      {:ok, view, _} = live(ctx.conn, @route)

      verify(view, ctx.target_enrollment, ctx.source_enrollment)
      view |> element("#preview_button") |> render_click()

      assert has_element?(view, "#preview_changes", "There is no progress to restore")
      assert has_element?(view, "#commit_button[disabled]")

      render_click(view, "commit", %{})
      assert has_element?(view, "#result", "There are no changes to commit.")
    end

    test "commit requires a preview", ctx do
      {:ok, view, _} = live(ctx.conn, @route)

      verify(view, ctx.target_enrollment, ctx.source_enrollment)
      render_click(view, "commit", %{})

      assert has_element?(view, "#result", "Preview changes before committing.")
    end

    test "editing the form after a commit allows a new verification", ctx do
      insert(:resource_access,
        user: ctx.source_user,
        section: ctx.section,
        resource: insert(:resource)
      )

      {:ok, view, _} = live(ctx.conn, @route)

      verify(view, ctx.target_enrollment, ctx.source_enrollment)
      view |> element("#preview_button") |> render_click()
      view |> element("#commit_button") |> render_click()

      view
      |> form("#verify_form", %{"source_user_id" => ""})
      |> render_change()

      assert has_element?(view, "#commit_button", "Commit Changes")
      refute has_element?(view, "#result", "Success")
    end
  end

  defp verify(view, target_enrollment, source_enrollment) do
    view
    |> form("#verify_form", %{
      "section_slug" => target_enrollment.section.slug,
      "target_user_id" => Integer.to_string(target_enrollment.user_id),
      "source_user_id" => Integer.to_string(source_enrollment.user_id)
    })
    |> render_submit()
  end
end
