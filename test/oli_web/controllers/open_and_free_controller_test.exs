defmodule OliWeb.OpenAndFreeControllerTest do
  use OliWeb.ConnCase

  import Oli.Factory

  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections
  alias Oli.Repo

  @create_attrs %{
    end_date: ~U[2010-04-17 00:00:00.000000Z],
    open_and_free: true,
    registration_open: true,
    start_date: ~U[2010-04-17 00:00:00.000000Z],
    title: "some title",
    context_id: "some context_id"
  }

  @invalid_attrs %{
    end_date: nil,
    open_and_free: nil,
    registration_open: nil,
    start_date: nil,
    title: nil,
    context_id: nil
  }

  describe "update independent section" do
    setup [:instructor_conn]

    test "records the settings that changed and ignores fields the form does not render", %{
      conn: conn,
      instructor: instructor
    } do
      section =
        insert(:section,
          type: :enrollable,
          open_and_free: true,
          registration_open: false,
          context_id: "original"
        )

      Sections.enroll(instructor.id, section.id, [
        Lti_1p3.Roles.ContextRoles.get_role(:context_instructor)
      ])

      conn =
        put(conn, ~p"/sections/independent/#{section.id}",
          section: %{
            "title" => "Renamed section",
            "start_date" => "2030-01-01T00:00",
            "end_date" => "2030-02-01T00:00",
            "registration_open" => "true",
            "context_id" => "pushed-context",
            "grade_passback_enabled" => "true",
            "requires_payment" => "true"
          }
        )

      assert redirected_to(conn) =~ "/sections/independent/"

      updated = Sections.get_section!(section.id)

      assert {updated.title, updated.registration_open, updated.context_id,
              updated.grade_passback_enabled, updated.requires_payment} ==
               {"Renamed section", true, "original", section.grade_passback_enabled,
                section.requires_payment}

      event =
        assert_audited(:section_settings_changed,
          section_id: section.id,
          actor: instructor,
          source: :api
        )

      assert event.changes["title"]["after"] == "Renamed section"
      assert event.changes["registration_open"]["after"] == true
    end

    test "an instructor who does not teach the section can neither view nor edit it", %{
      conn: conn
    } do
      section = insert(:section, type: :enrollable, open_and_free: true, title: "Not mine")

      assert conn |> get(~p"/sections/independent/#{section.id}") |> response(403)
      assert conn |> get(~p"/sections/independent/#{section.id}/edit") |> response(403)

      assert conn
             |> put(~p"/sections/independent/#{section.id}",
               section: %{
                 "title" => "Changed by a stranger",
                 "start_date" => "",
                 "end_date" => ""
               }
             )
             |> response(403)

      assert Sections.get_section!(section.id).title == "Not mine"
      assert audit_events(:section_settings_changed, section_id: section.id) == []
    end
  end

  describe "create independent section" do
    setup [:create_project_with_products, :instructor_conn]

    test "show create form for product", %{
      conn: conn,
      product_1: product_1
    } do
      conn =
        get(conn, ~p"/sections/independent/new?source_id=product%3A#{product_1.id}")

      assert html_response(conn, 200) =~ "Create Section"

      assert html_response(conn, 200) =~
               "<input id=\"section_source_id\" name=\"section[source_id]\" type=\"hidden\" value=\"product:#{product_1.id}\">"

      assert html_response(conn, 200) =~ "<input type=\"text\" value=\"Product 1\""
    end

    test "create section from product redirects to instructor dashboard manage page", %{
      conn: conn,
      product_1: product_1,
      instructor: instructor
    } do
      conn =
        post(conn, ~p"/sections/independent",
          section:
            Enum.into(@create_attrs, %{
              product_slug: product_1.slug,
              source_id: "product:#{product_1.id}"
            })
        )

      %{section_slug: section_slug} = redirected_params(conn)

      assert redirected_to(conn) == ~p"/sections/#{section_slug}/manage?section_created=true"

      section = Sections.get_section_by_slug(section_slug)

      event =
        assert_audited(:section_created, section_id: section.id, actor: instructor, source: :api)

      assert event.details["blueprint_id"] == product_1.id
      refute Phoenix.Flash.get(conn.assigns.flash, :section_created_setup)
      refute Phoenix.Flash.get(conn.assigns.flash, :info)

      conn = get(recycle(conn), redirected_to(conn))
      html = html_response(conn, 200)

      assert html =~ "Section created successfully!"
      assert html =~ "Course setup recommended"
      assert html =~ "Your course section has been created and is ready for configuration."
    end

    test "create section from a Project copies its learning model", %{
      conn: conn,
      project: project,
      instructor: instructor
    } do
      project =
        project
        |> Project.trusted_learning_model_changeset(%{learning_model_version: :lkt_aoa})
        |> Repo.update!()

      conn =
        post(conn, ~p"/sections/independent",
          section:
            Enum.into(@create_attrs, %{
              project_slug: project.slug,
              source_id: "project:#{project.id}"
            })
        )

      %{section_slug: section_slug} = redirected_params(conn)

      section = Sections.get_section_by_slug(section_slug)
      assert section.learning_model_version == :lkt_aoa

      assert_audited(:section_created,
        section_id: section.id,
        project_id: project.id,
        actor: instructor,
        source: :api
      )
    end

    test "renders errors when data is invalid", %{
      conn: conn,
      product_1: product_1
    } do
      conn =
        post(conn, ~p"/sections/independent",
          section:
            Enum.into(@invalid_attrs, %{
              product_slug: product_1.slug,
              source_id: "product:#{product_1.id}"
            })
        )

      assert html_response(conn, 200) =~ "Create Section"
    end
  end
end
