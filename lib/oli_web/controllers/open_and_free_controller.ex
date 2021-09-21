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
    sections =
      Sections.list_open_and_free_sections()
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
    with %{
           "project_slug" => project_slug,
           "start_date" => start_date,
           "end_date" => end_date,
           "timezone" => timezone
         } <-
           section_params,
         %{id: project_id} <- Course.get_project_by_slug(project_slug),
         publication <- Publishing.get_latest_published_publication_by_slug(project_slug) do
      {utc_start_date, utc_end_date} =
        parse_and_convert_start_end_dates_to_utc(start_date, end_date, timezone)

      section_params =
        section_params
        |> Map.put("base_project_id", project_id)
        |> Map.put("open_and_free", true)
        |> Map.put("context_id", UUID.uuid4())
        |> Map.put("start_date", utc_start_date)
        |> Map.put("end_date", utc_end_date)

      case Sections.create_section(section_params) do
        {:ok, section} ->
          {:ok, section} = Sections.create_section_resources(section, publication)

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
    section =
      Sections.get_section_preloaded!(id)
      |> convert_utc_to_section_tz()

    updates = Sections.check_for_available_publication_updates(section)
    render_workspace_page(conn, "show.html", section: section, updates: updates)
  end

  def edit(conn, %{"id" => id}) do
    section =
      Sections.get_section_preloaded!(id)
      |> convert_utc_to_section_tz()

    changeset = Sections.change_section(section)

    render_workspace_page(conn, "edit.html",
      section: section,
      changeset: changeset,
      timezones: Predefined.timezones()
    )
  end

  def update(conn, %{
        "id" => id,
        "section" =>
          %{"start_date" => start_date, "end_date" => end_date, "timezone" => timezone} =
            section_params
      }) do
    section = Sections.get_section_preloaded!(id)

    {utc_start_date, utc_end_date} =
      parse_and_convert_start_end_dates_to_utc(start_date, end_date, timezone)

    section_params =
      section_params
      |> Map.put("start_date", utc_start_date)
      |> Map.put("end_date", utc_end_date)

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

  defp parse_and_convert_start_end_dates_to_utc(start_date, end_date, from_timezone) do
    section_timezone = Timex.Timezone.get(from_timezone)
    utc_timezone = Timex.Timezone.get(:utc, Timex.now())

    utc_start_date =
      case start_date do
        start_date when start_date == nil or start_date == "" or not is_binary(start_date) ->
          start_date

        start_date ->
          start_date
          |> Timex.parse!("%m/%d/%Y %l:%M %p", :strftime)
          |> Timex.to_datetime(section_timezone)
          |> Timex.Timezone.convert(utc_timezone)
      end

    utc_end_date =
      case end_date do
        end_date when end_date == nil or end_date == "" or not is_binary(end_date) ->
          end_date

        end_date ->
          end_date
          |> Timex.parse!("%m/%d/%Y %l:%M %p", :strftime)
          |> Timex.to_datetime(section_timezone)
          |> Timex.Timezone.convert(utc_timezone)
      end

    {utc_start_date, utc_end_date}
  end

  defp convert_utc_to_section_tz(
         %Section{start_date: start_date, end_date: end_date, timezone: timezone} = section
       ) do
    timezone = Timex.Timezone.get(timezone, Timex.now())

    start_date =
      case start_date do
        start_date when start_date == nil or start_date == "" -> start_date
        start_date -> Timex.Timezone.convert(start_date, timezone)
      end

    end_date =
      case end_date do
        end_date when end_date == nil or end_date == "" -> start_date
        end_date -> Timex.Timezone.convert(end_date, timezone)
      end

    section
    |> Map.put(:start_date, start_date)
    |> Map.put(:end_date, end_date)
  end

  defp render_workspace_page(conn, template, assigns) do
    render(conn, template, Keyword.merge(assigns, active: :open_and_free, title: "Open and Free"))
  end
end
