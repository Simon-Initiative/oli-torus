defmodule OliWeb.OpenAndFreeController do
  use OliWeb, :controller

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section

  def index(conn, _params) do
    sections = Sections.list_open_and_free_sections()
    render_workspace_page(conn, "index.html", sections: sections)
  end

  def new(conn, _params) do
    changeset = Sections.change_section(%Section{open_and_free: true})
    render_workspace_page(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"section" => section_params}) do
    case Sections.create_section(section_params) do
      {:ok, section} ->
        conn
        |> put_flash(:info, "Open and free created successfully.")
        |> redirect(to: Routes.open_and_free_path(conn, :show, section))

      {:error, %Ecto.Changeset{} = changeset} ->
        render_workspace_page(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    section = Sections.get_section!(id)
    render_workspace_page(conn, "show.html", section: section)
  end

  def edit(conn, %{"id" => id}) do
    section = Sections.get_section!(id)
    changeset = Sections.change_section(section)
    render_workspace_page(conn, "edit.html", section: section, changeset: changeset)
  end

  def update(conn, %{"id" => id, "section" => section_params}) do
    section = Sections.get_section!(id)

    case Sections.update_section(section, section_params) do
      {:ok, section} ->
        conn
        |> put_flash(:info, "Open and free section updated successfully.")
        |> redirect(to: Routes.open_and_free_path(conn, :show, section))

      {:error, %Ecto.Changeset{} = changeset} ->
        render_workspace_page(conn, "edit.html", section: section, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    section = Sections.get_section!(id)
    {:ok, _section} = Sections.delete_section(section)

    conn
    |> put_flash(:info, "Open and free section deleted successfully.")
    |> redirect(to: Routes.open_and_free_path(conn, :index))
  end

  defp render_workspace_page(conn, template, assigns) do
    render conn, template, Keyword.merge(assigns, [active: :open_and_free, title: "Open and Free"])
  end

end
