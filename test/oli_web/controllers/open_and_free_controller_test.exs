defmodule OliWeb.OpenAndFreeControllerTest do
  use OliWeb.ConnCase
  alias Oli.Delivery.Sections
  alias Lti_1p3.Tool.ContextRoles

  @create_attrs %{
    end_date: ~U[2010-04-17 00:00:00.000000Z],
    open_and_free: true,
    registration_open: true,
    start_date: ~U[2010-04-17 00:00:00.000000Z],
    timezone: "America/Los_Angeles",
    title: "some title",
    context_id: "some context_id"
  }
  @update_attrs %{
    end_date: ~U[2010-05-18 00:00:00.000000Z],
    open_and_free: true,
    registration_open: false,
    start_date: ~U[2010-05-18 00:00:00.000000Z],
    timezone: "US/Mountain",
    title: "some updated title",
    context_id: "some updated context_id"
  }
  @invalid_attrs %{
    end_date: nil,
    open_and_free: nil,
    registration_open: nil,
    start_date: nil,
    timezone: nil,
    title: nil,
    context_id: nil
  }

  setup [:admin_conn]

  describe "index" do
    test "lists all open_and_free", %{conn: conn} do
      conn = get(conn, Routes.admin_open_and_free_path(conn, :index))
      assert html_response(conn, 200) =~ "Section"
    end
  end

  describe "new" do
    setup [:create_fixtures]

    test "renders form from product", %{conn: conn, section: section} do
      conn =
        get(conn, Routes.admin_open_and_free_path(conn, :new, source_id: "product:#{section.id}"))

      assert html_response(conn, 200) =~ "Source Product"
      assert conn.resp_body =~ "Registration Open"

      assert conn.resp_body =~
               ~r/<input .* id="section_registration_open" .* value="true"/

      assert conn.resp_body =~ "Requires Enrollment"

      assert conn.resp_body =~
               ~r/<input .* id="section_requires_enrollment" .* value="true"/
    end

    test "renders form from publication", %{conn: conn, publication: publication} do
      conn =
        get(
          conn,
          Routes.admin_open_and_free_path(conn, :new, source_id: "publication:#{publication.id}")
        )

      assert html_response(conn, 200) =~ "Source Project"
      assert conn.resp_body =~ "Registration Open"

      assert conn.resp_body =~
               ~r/<input .* id="section_registration_open" .* value="true"/

      assert conn.resp_body =~ "Requires Enrollment"

      assert conn.resp_body =~
               ~r/<input .* id="section_requires_enrollment" .* value="true"/
    end

    test "renders form from project", %{conn: conn, project: project} do
      conn =
        get(conn, Routes.admin_open_and_free_path(conn, :new, source_id: "project:#{project.id}"))

      assert html_response(conn, 200) =~ "Source Project"
      assert conn.resp_body =~ "Registration Open"

      assert conn.resp_body =~
               ~r/<input .* id="section_registration_open" .* value="true"/

      assert conn.resp_body =~ "Requires Enrollment"

      assert conn.resp_body =~
               ~r/<input .* id="section_requires_enrollment" .* value="true"/
    end
  end

  describe "create open_and_free" do
    setup [:create_fixtures]

    test "redirects to show when data is valid", %{
      conn: conn,
      admin: admin,
      project: project,
      user: user,
      revision1: revision1
    } do
      conn =
        post(conn, Routes.admin_open_and_free_path(conn, :create),
          section: Enum.into(@create_attrs, %{project_slug: project.slug})
        )

      assert %{section_slug: slug} = redirected_params(conn)
      assert redirected_to(conn) == Routes.live_path(conn, OliWeb.Sections.OverviewView, slug)

      conn = recycle_author_session(conn, admin)

      # can access open and free index and pages
      section = Sections.get_section_by(slug: slug)

      conn =
        conn
        |> recycle()
        |> get(Routes.page_delivery_path(conn, :index, section.slug))

      assert html_response(conn, 302) =~ "/sections/#{section.slug}/enroll"

      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        conn
        |> recycle_user_session(user)
        |> get(Routes.page_delivery_path(conn, :page, section.slug, revision1.slug))

      assert html_response(conn, 200) =~ "<h1 class=\"title\">"
    end
  end

  describe "edit open_and_free" do
    setup [:create_fixtures]

    test "renders form for editing chosen open_and_free", %{conn: conn, section: section} do
      conn = get(conn, Routes.admin_open_and_free_path(conn, :edit, section))
      assert html_response(conn, 200) =~ "Edit Section"
    end
  end

  describe "update open_and_free section" do
    setup [:create_fixtures]

    test "redirects when data is valid", %{conn: conn, admin: admin, section: section} do
      conn =
        put(conn, Routes.admin_open_and_free_path(conn, :update, section), section: @update_attrs)

      assert redirected_to(conn) == Routes.admin_open_and_free_path(conn, :show, section)

      conn = recycle_author_session(conn, admin)

      conn = get(conn, Routes.admin_open_and_free_path(conn, :show, section))
      assert html_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn, section: section} do
      conn =
        put(conn, Routes.admin_open_and_free_path(conn, :update, section), section: @invalid_attrs)

      assert html_response(conn, 200) =~ "Edit Section"
    end
  end

  defp create_fixtures(_) do
    user = user_fixture()
    author = author_fixture()

    %{project: project, institution: institution, revision1: revision1} =
      Oli.Seeder.base_project_with_resource(author)

    {:ok, publication} = Oli.Publishing.publish_project(project, "some changes")

    section =
      section_fixture(%{
        institution_id: institution.id,
        base_project_id: project.id,
        context_id: UUID.uuid4(),
        open_and_free: true
      })

    %{
      section: section,
      project: project,
      publication: publication,
      user: user,
      revision1: revision1
    }
  end
end
