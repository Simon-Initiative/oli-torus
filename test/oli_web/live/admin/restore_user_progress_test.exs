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

      view
      |> element("#target_enrollment_id")
      |> render_hook("target_enrollment", %{
        "id" => "target_enrollment_id",
        "value" => Integer.to_string(target_enrollment.id)
      })

      view
      |> element("#source_enrollment_id")
      |> render_hook("source_enrollment", %{
        "id" => "source_enrollment_id",
        "value" => Integer.to_string(source_enrollment.id)
      })

      render_click(view, "preview", %{})

      html = render(view)

      assert html =~ "User Records"
      assert html =~ Integer.to_string(true_user.id)
      assert html =~ Integer.to_string(other_user.id)

      # Expect a proposed change referencing the other_access id (reassign to true_user)
      assert html =~ inspect(other_access.id)
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

      view
      |> element("#target_enrollment_id")
      |> render_hook("target_enrollment", %{
        "id" => "target_enrollment_id",
        "value" => Integer.to_string(target_enrollment.id)
      })

      view
      |> element("#source_enrollment_id")
      |> render_hook("source_enrollment", %{
        "id" => "source_enrollment_id",
        "value" => Integer.to_string(source_enrollment.id)
      })

      render_click(view, "preview", %{})
      render_click(view, "commit", %{})

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

      view
      |> element("#target_enrollment_id")
      |> render_hook("target_enrollment", %{
        "id" => "target_enrollment_id",
        "value" => Integer.to_string(target_enrollment.id)
      })

      view
      |> element("#source_enrollment_id")
      |> render_hook("source_enrollment", %{
        "id" => "source_enrollment_id",
        "value" => Integer.to_string(source_enrollment.id)
      })

      render_click(view, "preview", %{})
      render_click(view, "commit", %{})

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
end
