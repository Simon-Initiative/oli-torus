defmodule Oli.Plugs.MaybeGatedResourceTest do
  use OliWeb.ConnCase

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Gating
  alias Oli.Seeder
  alias Lti_1p3.Tool.ContextRoles
  alias OliWeb.Router.Helpers, as: Routes

  describe "maybe_gated_resource plug" do
    setup [:setup_session]

    test "allows section overview access for student", %{
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

    test "allows access to gated resource with an open gating condition", %{
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
          data: %{start_datetime: yesterday(), end_datetime: tomorrow()}
        })

      {:ok, section} = Gating.update_resource_gating_index(section)

      conn =
        conn
        |> get(Routes.page_delivery_path(conn, :page, section.slug, revision.slug))

      assert html_response(conn, 200) =~ "<h1 class=\"title\">"
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
        |> get(Routes.page_delivery_path(conn, :page, section.slug, revision.slug))

      assert html_response(conn, 403) =~
               "You are trying to access a resource that is gated by the following condition"

      assert html_response(conn, 403) =~
               "#{revision.title} is scheduled to end"
    end
  end

  defp setup_session(%{conn: conn}) do
    user = user_fixture()

    map = Seeder.base_project_with_resource4()

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

    {:ok,
     conn: conn,
     map: map,
     user: user,
     project: map.project,
     section: map.section_1,
     revision: map.revision1}
  end
end
