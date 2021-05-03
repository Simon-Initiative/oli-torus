defmodule OliWeb.OpenAndFreeController do
  use OliWeb, :controller

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Predefined
  alias Oli.Authoring.Course
  alias Oli.Publishing

  def index(conn, _params) do
    sections = Sections.list_open_and_free_sections()
    render_workspace_page(conn, "index.html", sections: sections)
  end

  @doc """
  Provides API access to the open and free sections that are open for registration.
  """
  def index_api(conn, _params) do
    sections = Sections.list_open_and_free_sections()
    |> Enum.filter(fn s -> s.registration_open end)
    |> Enum.map(fn section ->
      %{
        slug: section.slug,
        url: Routes.page_delivery_path(conn, :index, section.slug)
      }
    end)

    json(conn, sections)
  end

  def new(conn, _params) do
    changeset = Sections.change_section(%Section{open_and_free: true, registration_open: true})
    render_workspace_page(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"section" => section_params}) do
    with %{"project_slug" => project_slug} <- section_params,
         %{id: project_id} <- Course.get_project_by_slug(project_slug),
         %{id: publication_id} <-
           Publishing.get_latest_published_publication_by_slug!(project_slug) do
      section_params =
        section_params
        |> Map.put("project_id", project_id)
        |> Map.put("publication_id", publication_id)
        |> Map.put("open_and_free", true)
        |> Map.put("context_id", UUID.uuid4())

      case Sections.create_section(section_params) do
        {:ok, section} ->
          conn
          |> put_flash(:info, "Open and free created successfully.")
          |> redirect(to: Routes.open_and_free_path(conn, :show, section))

        {:error, %Ecto.Changeset{} = changeset} ->
          render_workspace_page(conn, "new.html", changeset: changeset)
      end
    else
      _ ->
        changeset =
          Sections.change_section(%Section{open_and_free: true})
          |> Ecto.Changeset.add_error(:project_id, "invalid project")

        render_workspace_page(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    section = Sections.get_section_preloaded!(id)
    render_workspace_page(conn, "show.html", section: section)
  end

  def edit(conn, %{"id" => id}) do
    section = Sections.get_section_preloaded!(id)
    changeset = Sections.change_section(section)

    render_workspace_page(conn, "edit.html",
      section: section,
      changeset: changeset,
      timezones: Predefined.timezones()
    )
  end

  def update(conn, %{"id" => id, "section" => section_params}) do
    section = Sections.get_section_preloaded!(id)

    case Sections.update_section(section, section_params) do
      {:ok, section} ->
        conn
        |> put_flash(:info, "Open and free section updated successfully.")
        |> redirect(to: Routes.open_and_free_path(conn, :show, section))

      {:error, %Ecto.Changeset{} = changeset} ->
        render_workspace_page(conn, "edit.html",
          section: section,
          changeset: changeset,
          timezones: Predefined.timezones()
        )
    end
  end

  defp render_workspace_page(conn, template, assigns) do
    render(conn, template, Keyword.merge(assigns, active: :open_and_free, title: "Open and Free"))
  end
end
