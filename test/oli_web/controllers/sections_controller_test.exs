defmodule OliWeb.SectionsControllerTest do
  use OliWeb.ConnCase

  import Oli.Factory

  alias Oli.Accounts.SystemRole

  describe "export_csv/2" do
    setup do
      admin =
        Oli.AccountsFixtures.author_fixture(%{system_role_id: SystemRole.role_id().system_admin})

      institution = insert(:institution, name: "Institution One")
      base_project = insert(:project, title: "Project One", authors: [])
      blueprint = insert(:section, title: "Blueprint Base", type: :enrollable)
      tag = insert(:tag, name: "Important")

      active_section =
        insert(:section,
          type: :enrollable,
          title: "Alpha Section",
          slug: "alpha-section",
          start_date: DateTime.utc_now() |> DateTime.add(-3600, :second),
          end_date: DateTime.utc_now() |> DateTime.add(3600, :second),
          base_project: base_project,
          blueprint: blueprint,
          institution: institution,
          requires_payment: true,
          amount: Money.new(:USD, 1000)
        )

      insert(:section_tag, section: active_section, tag: tag)

      inactive_section =
        insert(:section,
          type: :enrollable,
          title: "Beta Section",
          start_date: DateTime.utc_now() |> DateTime.add(-7 * 86_400, :second),
          end_date: DateTime.utc_now() |> DateTime.add(-2 * 86_400, :second),
          base_project: base_project
        )

      %{
        admin: admin,
        active_section: active_section,
        inactive_section: inactive_section,
        tag: tag
      }
    end

    test "admin can export sections with headers and sorted content", %{
      conn: conn,
      admin: admin,
      active_section: active_section,
      inactive_section: inactive_section,
      tag: tag
    } do
      conn =
        conn
        |> log_in_author(admin)
        |> get(~p"/admin/sections/export?sort_by=title&sort_order=asc")

      assert response(conn, 200)
      assert get_resp_header(conn, "content-type") == ["text/csv"]

      csv = response(conn, 200)
      lines = csv |> String.split("\n", trim: true)

      # header + rows
      assert hd(lines) =~
               "Title,Section ID,Tags,# Enrolled,Cost,Start,End,Base Project/Product,Base ID,Instructors,Institution,Delivery,Status"

      [first_row | _] = tl(lines)
      assert String.contains?(first_row, active_section.title)
      assert String.contains?(first_row, active_section.slug)
      assert String.contains?(first_row, tag.name)
      # Base slug/title can come from blueprint or base project; blueprint wins when present
      base_slug = active_section.blueprint.slug || active_section.base_project.slug
      assert String.contains?(first_row, base_slug)
      assert String.contains?(csv, inactive_section.title)
    end

    test "export respects active_today filter", %{
      conn: conn,
      admin: admin,
      active_section: active_section,
      inactive_section: inactive_section
    } do
      conn =
        conn
        |> log_in_author(admin)
        |> get(~p"/admin/sections/export?active_today=true")

      csv = response(conn, 200)

      assert String.contains?(csv, active_section.title)
      refute String.contains?(csv, inactive_section.title)
    end
  end
end
