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

  describe "preview and commit" do
    setup [:admin_conn]

    test "preview lists users and proposed changes for practice pages where true user has no access",
         %{conn: conn} do
      # Arrange: create users and a section; enroll both, but ensure independent_learner == false to be included
      institution_section = insert(:section)
      true_user = insert(:user, independent_learner: false, email: "u1@example.edu")
      other_user = insert(:user, independent_learner: false, email: "u1@example.edu")

      insert(:enrollment, user: true_user, section: institution_section)
      insert(:enrollment, user: other_user, section: institution_section)

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

      # Provide the email shared by both users
      view |> element("#email") |> render_hook("email", %{"value" => true_user.email})
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

      insert(:enrollment, user: true_user, section: section)
      insert(:enrollment, user: other_user, section: section)

      resource = insert(:resource)
      access = insert(:resource_access, user: other_user, section: section, resource: resource)

      {:ok, view, _} = live(conn, @route)
      view |> element("#email") |> render_hook("email", %{"value" => true_user.email})
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

      insert(:enrollment, user: true_user, section: section)
      insert(:enrollment, user: other_user, section: section)

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
      view |> element("#email") |> render_hook("email", %{"value" => true_user.email})
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
