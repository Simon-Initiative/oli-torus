defmodule OliWeb.OpenAndFreeControllerTest do
  use OliWeb.ConnCase

  @create_attrs %{
    end_date: ~D[2010-04-17],
    open_and_free: true,
    registration_open: true,
    start_date: ~D[2010-04-17],
    time_zone: "some time_zone",
    title: "some title",
    context_id: "some context_id"
  }
  @update_attrs %{
    end_date: ~D[2011-05-18],
    open_and_free: true,
    registration_open: false,
    start_date: ~D[2011-05-18],
    time_zone: "some updated time_zone",
    title: "some updated title",
    context_id: "some updated context_id"
  }
  @invalid_attrs %{
    end_date: nil,
    open_and_free: nil,
    registration_open: nil,
    start_date: nil,
    time_zone: nil,
    title: nil,
    context_id: nil
  }

  setup [:admin_conn]

  describe "index" do
    test "lists all open_and_free", %{conn: conn} do
      conn = get(conn, Routes.open_and_free_path(conn, :index))
      assert html_response(conn, 200) =~ "Open and Free"
    end
  end

  describe "new open_and_free" do
    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.open_and_free_path(conn, :new))
      assert html_response(conn, 200) =~ "Create Open and Free Section"
    end
  end

  describe "create open_and_free" do
    setup [:create_fixtures]

    test "redirects to show when data is valid", %{conn: conn, admin: admin, project: project} do
      conn =
        post(conn, Routes.open_and_free_path(conn, :create),
          section: Enum.into(@create_attrs, %{project_slug: project.slug})
        )

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == Routes.open_and_free_path(conn, :show, id)

      conn = recycle_author_session(conn, admin)

      conn = get(conn, Routes.open_and_free_path(conn, :show, id))
      assert html_response(conn, 200) =~ "Open and free"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.open_and_free_path(conn, :create), section: @invalid_attrs)
      assert html_response(conn, 200) =~ "Create Open and Free Section"
    end
  end

  describe "edit open_and_free" do
    setup [:create_fixtures]

    test "renders form for editing chosen open_and_free", %{conn: conn, section: section} do
      conn = get(conn, Routes.open_and_free_path(conn, :edit, section))
      assert html_response(conn, 200) =~ "Edit Open and Free Section"
    end
  end

  describe "update open_and_free section" do
    setup [:create_fixtures]

    test "redirects when data is valid", %{conn: conn, admin: admin, section: section} do
      conn = put(conn, Routes.open_and_free_path(conn, :update, section), section: @update_attrs)
      assert redirected_to(conn) == Routes.open_and_free_path(conn, :show, section)

      conn = recycle_author_session(conn, admin)

      conn = get(conn, Routes.open_and_free_path(conn, :show, section))
      assert html_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn, section: section} do
      conn = put(conn, Routes.open_and_free_path(conn, :update, section), section: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Open and Free Section"
    end
  end

  defp create_fixtures(_) do
    author = author_fixture()

    %{project: project, institution: institution} = Oli.Seeder.base_project_with_resource(author)

    {:ok, publication} = Oli.Publishing.publish_project(project)

    section =
      section_fixture(%{
        institution_id: institution.id,
        project_id: project.id,
        publication_id: publication.id,
        context_id: UUID.uuid4(),
        open_and_free: true
      })

    %{section: section, project: project, publication: publication}
  end
end
