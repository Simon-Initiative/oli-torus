defmodule OliWeb.Admin.RecommendationFeedbackLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.InstructorDashboard.Recommendations.{RecommendationFeedback, RecommendationInstance}
  alias Oli.Repo

  describe "mount/3" do
    test "redirects if user is not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/admin/ai_recommendation_feedback")
      assert redirected_to(conn) == ~p"/authors/log_in"
    end

    test "redirects if user is not a system admin", %{conn: conn} do
      author = insert(:author)
      conn = Plug.Test.init_test_session(conn, %{})

      {:error, {:redirect, %{to: path, flash: flash}}} =
        conn
        |> log_in_author(author)
        |> live(~p"/admin/ai_recommendation_feedback")

      assert path == "/workspaces/course_author"
      assert flash["error"] =~ "You are not authorized"
    end

    test "renders AI custom feedback table for system admin", %{conn: conn} do
      admin = insert(:author, system_role_id: Oli.Accounts.SystemRole.role_id().system_admin)
      section = insert(:section, title: "Algebra Section", slug: "algebra-101")
      user = insert(:user, name: "Ada Lovelace", email: "ada@example.org")

      recommendation =
        %RecommendationInstance{}
        |> RecommendationInstance.changeset(%{
          section_id: section.id,
          container_type: :course,
          generation_mode: :implicit,
          state: :ready,
          message: "Recommendation body",
          prompt_version: "v1",
          prompt_snapshot: %{},
          response_metadata: %{},
          generated_by_user_id: user.id
        })
        |> Repo.insert!()

      %RecommendationFeedback{}
      |> RecommendationFeedback.changeset(%{
        recommendation_instance_id: recommendation.id,
        user_id: user.id,
        feedback_type: :thumbs_up
      })
      |> Repo.insert!()

      %RecommendationFeedback{}
      |> RecommendationFeedback.changeset(%{
        recommendation_instance_id: recommendation.id,
        user_id: user.id,
        feedback_type: :additional_text,
        feedback_text: "Need more specific remediation steps."
      })
      |> Repo.insert!()

      {:ok, _view, html} =
        conn
        |> log_in_author(admin)
        |> live(~p"/admin/ai_recommendation_feedback")

      assert html =~ "AI Custom Feedback"
      assert html =~ "Need more specific remediation steps."
      assert html =~ "Ada Lovelace"
      assert html =~ "algebra-101"
      assert html =~ "Thumbs up"
    end
  end
end
