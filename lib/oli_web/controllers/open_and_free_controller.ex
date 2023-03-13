defmodule OliWeb.OpenAndFreeController do
  use OliWeb, :controller

  alias Oli.{Repo, Publishing, Branding}
  alias Oli.Delivery
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Authoring.Course
  alias OliWeb.Common.{Breadcrumb, FormatDateTime, SessionContext}
  alias Lti_1p3.Tool.ContextRoles

  alias OliWeb.Router.Helpers, as: Routes

  plug :add_assigns

  defp add_assigns(conn, _opts) do
    merge_assigns(conn,
      route: determine_route(conn),
      active: :open_and_free,
      title: "Open and Free"
    )
  end

  defp available_brands() do
    Branding.list_brands()
    |> Enum.map(fn brand -> {brand.name, brand.id} end)
  end

  defp source_info(source_id) do
    case source_id do
      "product:" <> id ->
        {Sections.get_section!(String.to_integer(id)), "Source Product", :product_slug}

      "publication:" <> id ->
        publication =
          Oli.Publishing.get_publication!(String.to_integer(id)) |> Repo.preload(:project)

        {publication.project, "Source Project", :project_slug}

      "project:" <> id ->
        project = Course.get_project!(id)

        {project, "Source Project", :project_slug}
    end
  end

  def index(conn, _params) do
    render(conn, "index.html",
      sections: Sections.list_open_and_free_sections(),
      breadcrumbs: set_breadcrumbs()
    )
  end

  def new(conn, %{"source_id" => source_id}) do
    {source, source_label, source_param_name} = source_info(source_id)

    render(conn, "new.html",
      context: SessionContext.init(conn),
      breadcrumbs: set_breadcrumbs() |> new_breadcrumb(),
      changeset: Sections.change_independent_learner_section(%Section{registration_open: true}),
      source_id: source_id,
      source: source,
      source_label: source_label,
      source_param_name: source_param_name,
      available_brands: available_brands()
    )
  end

  def create(conn, %{"section" => %{"product_slug" => _} = section_params}) do
    with %{
           "product_slug" => product_slug,
           "start_date" => start_date,
           "end_date" => end_date
         } <-
           section_params,
         blueprint <- Sections.get_section_by_slug(product_slug) do
      context = SessionContext.init(conn)

      project = Oli.Repo.get(Oli.Authoring.Course.Project, blueprint.base_project_id)

      utc_start_date = FormatDateTime.datestring_to_utc_datetime(start_date, context)
      utc_end_date = FormatDateTime.datestring_to_utc_datetime(end_date, context)

      section_params =
        to_atom_keys(section_params)
        |> Map.merge(%{
          blueprint_id: blueprint.id,
          type: :enrollable,
          open_and_free: true,
          has_experiments: project.has_experiments,
          context_id: UUID.uuid4(),
          start_date: utc_start_date,
          end_date: utc_end_date
        })

      case create_from_product(conn, blueprint, section_params) do
        {:ok, section} ->
          conn
          |> put_flash(:info, "Section created successfully.")
          |> redirect(
            to: Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.OverviewView, section.slug)
          )

        _ ->
          changeset =
            Sections.change_independent_learner_section(%Section{})
            |> Ecto.Changeset.add_error(:title, "invalid settings")

          source_id = section_params[:source_id]
          {source, source_label, source_param_name} = source_info(source_id)

          render(conn, "new.html",
            changeset: changeset,
            breadcrumbs: set_breadcrumbs() |> new_breadcrumb(),
            source_id: source_id,
            source: source,
            source_label: source_label,
            source_param_name: source_param_name,
            available_brands: available_brands()
          )
      end
    else
      _ ->
        changeset =
          Sections.change_independent_learner_section(%Section{})
          |> Ecto.Changeset.add_error(:title, "invalid settings")

        source_id = section_params[:source_id]
        {source, source_label, source_param_name} = source_info(source_id)

        render(conn, "new.html",
          changeset: changeset,
          breadcrumbs: set_breadcrumbs() |> new_breadcrumb(),
          source_id: source_id,
          source: source,
          source_label: source_label,
          source_param_name: source_param_name,
          available_brands: available_brands()
        )
    end
  end

  def create(conn, %{"section" => section_params}) do
    with %{
           "project_slug" => project_slug,
           "start_date" => start_date,
           "end_date" => end_date
         } <-
           section_params,
         %{id: project_id, has_experiments: has_experiments} <- Course.get_project_by_slug(project_slug),
         publication <- Publishing.get_latest_published_publication_by_slug(project_slug) |> Repo.preload(:project) do

      context = SessionContext.init(conn)

      utc_start_date = FormatDateTime.datestring_to_utc_datetime(start_date, context)
      utc_end_date = FormatDateTime.datestring_to_utc_datetime(end_date, context)

      customizations = case publication.project.customizations do
        nil -> nil
        labels -> Map.from_struct(labels)
      end

      section_params =
        section_params
        |> Map.put("type", :enrollable)
        |> Map.put("base_project_id", project_id)
        |> Map.put("open_and_free", true)
        |> Map.put("context_id", UUID.uuid4())
        |> Map.put("start_date", utc_start_date)
        |> Map.put("end_date", utc_end_date)
        |> Map.put("customizations", customizations)
        |> Map.put("has_experiments", has_experiments)

      case create_from_publication(conn, publication, section_params) do
        {:ok, section} ->
          conn
          |> put_flash(:info, "Section created successfully.")
          |> redirect(
            to: Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.OverviewView, section.slug)
          )

        {:error, changeset} ->
          source_id = section_params["source_id"]
          {source, source_label, source_param_name} = source_info(source_id)

          render(conn, "new.html",
            changeset: changeset,
            breadcrumbs: set_breadcrumbs() |> new_breadcrumb(),
            source_id: source_id,
            source: source,
            source_label: source_label,
            source_param_name: source_param_name,
            available_brands: available_brands()
          )
      end
    else
      _ ->
        changeset =
          Sections.change_independent_learner_section(%Section{})
          |> Ecto.Changeset.add_error(:project_id, "invalid project")

        source_id = section_params["source_id"]
        {source, source_label, source_param_name} = source_info(source_id)

        render(conn, "new.html",
          changeset: changeset,
          breadcrumbs: set_breadcrumbs() |> new_breadcrumb(),
          source_id: source_id,
          source: source,
          source_label: source_label,
          source_param_name: source_param_name,
          available_brands: available_brands()
        )
    end
  end

  def show(conn, %{"id" => id}) do
    context = SessionContext.init(conn)

    section =
      Sections.get_section_preloaded!(id)
      |> Sections.localize_section_start_end_datetimes(context)

    render(conn, "show.html",
      context: context,
      section: section,
      updates: Sections.check_for_available_publication_updates(section),
      breadcrumbs: set_breadcrumbs() |> show_breadcrumb()
    )
  end

  def edit(conn, %{"id" => id}) do
    context = SessionContext.init(conn)

    section =
      Sections.get_section_preloaded!(id)
      |> Sections.localize_section_start_end_datetimes(context)

    render(conn, "edit.html",
      context: context,
      breadcrumbs: set_breadcrumbs() |> edit_breadcrumb(),
      section: section,
      changeset: Sections.change_section(section),
      available_brands: available_brands()
    )
  end

  def update(conn, %{
        "id" => id,
        "section" =>
          %{"start_date" => start_date, "end_date" => end_date} =
            section_params
      }) do
    section = Sections.get_section_preloaded!(id)

    context = SessionContext.init(conn)

    utc_start_date = FormatDateTime.datestring_to_utc_datetime(start_date, context)
    utc_end_date = FormatDateTime.datestring_to_utc_datetime(end_date, context)

    section_params =
      section_params
      |> Map.put("start_date", utc_start_date)
      |> Map.put("end_date", utc_end_date)

    case Sections.update_section(section, section_params) do
      {:ok, section} ->
        conn
        |> put_flash(:info, "Section updated successfully.")
        |> redirect(to: OliWeb.OpenAndFreeView.get_path([conn.assigns.route, :show, section]))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html",
          context: context,
          breadcrumbs: set_breadcrumbs() |> edit_breadcrumb(),
          section: section,
          changeset: changeset,
          available_brands: available_brands()
        )
    end
  end

  ###
  ### Helpers
  ###

  # This controller is used across two scopes (admin and independent learner
  # section management, so template links need to know where to route)
  defp determine_route(conn) do
    if Enum.member?(conn.path_info, "admin") do
      :admin
    else
      :independent_learner
    end
  end

  # The OpenAndFree controller is used with multiple routes. Breadcrumbs
  # are only needed for the authoring admin route.
  def set_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb()
    |> breadcrumb()
  end

  def breadcrumb(previous) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Open and Free Sections",
          link: Routes.admin_open_and_free_path(OliWeb.Endpoint, :index)
        })
      ]
  end

  def edit_breadcrumb(previous) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Edit"
        })
      ]
  end

  def new_breadcrumb(previous) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "New"
        })
      ]
  end

  def show_breadcrumb(previous) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Show"
        })
      ]
  end

  defp to_atom_keys(map) do
    Map.keys(map)
    |> Enum.reduce(%{}, fn k, m ->
      Map.put(m, String.to_existing_atom(k), Map.get(map, k))
    end)
  end

  defp create_from_product(conn, blueprint, section_params) do
    Repo.transaction(fn ->
      with {:ok, section} <- Oli.Delivery.Sections.Blueprint.duplicate(blueprint, section_params),
           {:ok, _} <- Sections.rebuild_contained_pages(section),
           {:ok, _maybe_enrollment} <- enroll(conn, section) do
        section
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp create_from_publication(conn, publication, section_params) do
    Repo.transaction(fn ->
      with {:ok, section} <- Sections.create_section(section_params),
           {:ok, section} <- Sections.create_section_resources(section, publication),
           {:ok, _} <- Sections.rebuild_contained_pages(section),
           {:ok, _enrollment} <- enroll(conn, section),
           {:ok, updated_section} <- Delivery.maybe_update_section_contains_explorations(section) do
        updated_section
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  # Enroll a user as a section instructor ONLY if it is a delivery user.
  # Router plugs handle user auth, so a user must be present here if in
  # delivery (independent learner) mode.
  defp enroll(conn, section) do
    if is_nil(conn.assigns.current_user) do
      {:ok, nil}
    else
      Sections.enroll(conn.assigns.current_user.id, section.id, [
        ContextRoles.get_role(:context_instructor)
      ])
    end
  end
end
