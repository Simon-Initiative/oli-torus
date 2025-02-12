defmodule OliWeb.OpenAndFreeController do
  use OliWeb, :controller

  alias Oli.{Repo, Publishing, Branding}
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.PostProcessing
  alias Oli.Delivery.Sections.Section
  alias Oli.Authoring.Course
  alias OliWeb.Common.{FormatDateTime}
  alias Lti_1p3.Tool.ContextRoles

  alias OliWeb.Router.Helpers, as: Routes

  plug :add_assigns

  defp add_assigns(conn, _opts) do
    merge_assigns(conn,
      route: :independent_learner,
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

  def new(conn, %{"source_id" => source_id}) do
    {source, source_label, source_param_name} = source_info(source_id)

    render(conn, "new.html",
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
      project = Oli.Repo.get(Oli.Authoring.Course.Project, blueprint.base_project_id)

      utc_start_date = FormatDateTime.datestring_to_utc_datetime(start_date, conn.assigns.ctx)
      utc_end_date = FormatDateTime.datestring_to_utc_datetime(end_date, conn.assigns.ctx)

      section_params =
        to_atom_keys(section_params)
        |> Map.merge(%{
          blueprint_id: blueprint.id,
          type: :enrollable,
          open_and_free: true,
          has_experiments: project.has_experiments,
          context_id: UUID.uuid4(),
          start_date: utc_start_date,
          end_date: utc_end_date,
          page_prompt_template: Oli.Conversation.DefaultPrompts.get_prompt("page_prompt"),
          analytics_version: :v2
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
         %{id: project_id, has_experiments: has_experiments} <-
           Course.get_project_by_slug(project_slug),
         publication <-
           Publishing.get_latest_published_publication_by_slug(project_slug)
           |> Repo.preload(:project) do
      utc_start_date = FormatDateTime.datestring_to_utc_datetime(start_date, conn.assigns.ctx)
      utc_end_date = FormatDateTime.datestring_to_utc_datetime(end_date, conn.assigns.ctx)

      customizations =
        case publication.project.customizations do
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
        |> Map.put(
          "page_prompt_template",
          Oli.Conversation.DefaultPrompts.get_prompt("page_prompt")
        )
        |> Map.put("analytics_version", :v2)

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
          source_id: source_id,
          source: source,
          source_label: source_label,
          source_param_name: source_param_name,
          available_brands: available_brands()
        )
    end
  end

  def show(conn, %{"id" => id}) do
    section =
      Sections.get_section_preloaded!(id)
      |> Sections.localize_section_start_end_datetimes(conn.assigns.ctx)

    render(conn, "show.html",
      section: section,
      updates: Sections.check_for_available_publication_updates(section)
    )
  end

  def edit(conn, %{"id" => id}) do
    section =
      Sections.get_section_preloaded!(id)
      |> Sections.localize_section_start_end_datetimes(conn.assigns.ctx)

    render(conn, "edit.html",
      section: section,
      changeset: Sections.change_section(section),
      available_brands: available_brands()
    )
  end

  def update(conn, %{
        "id" => id,
        "section" => %{"start_date" => start_date, "end_date" => end_date} = section_params
      }) do
    section = Sections.get_section_preloaded!(id)

    utc_start_date = FormatDateTime.datestring_to_utc_datetime(start_date, conn.assigns.ctx)
    utc_end_date = FormatDateTime.datestring_to_utc_datetime(end_date, conn.assigns.ctx)

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
          section: section,
          changeset: changeset,
          available_brands: available_brands()
        )
    end
  end

  ###
  ### Helpers
  ###

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
           {:ok, _} <- Sections.rebuild_contained_objectives(section),
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
           {:ok, _} <- Sections.rebuild_contained_objectives(section),
           {:ok, _enrollment} <- enroll(conn, section) do
        PostProcessing.apply(section, :all)
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
