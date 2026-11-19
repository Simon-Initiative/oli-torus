defmodule OliWeb.OpenAndFreeController do
  use OliWeb, :controller

  alias Oli.{Repo, Publishing, Branding}
  alias Oli.Delivery.Sections
  alias Oli.Auditing.Context
  alias Oli.Delivery.Sections.Audited, as: SectionsAudited
  alias Oli.Delivery.Sections.Section
  alias Oli.Authoring.Course
  alias OliWeb.Common.{FormatDateTime}

  alias OliWeb.Router.Helpers, as: Routes

  plug :add_assigns
  plug :authorize_section when action in [:show, :edit, :update]

  defp add_assigns(conn, _opts) do
    merge_assigns(conn,
      route: :independent_learner,
      active: :open_and_free,
      title: "Open and Free"
    )
  end

  # Only instructors and LMS admins of the section may view or edit it.
  defp authorize_section(%Plug.Conn{params: %{"id" => id}} = conn, _opts) do
    section = Sections.get_section_preloaded!(id)
    user = conn.assigns.current_user

    case Sections.is_instructor?(user, section.slug) or Sections.is_admin?(user, section.slug) do
      true ->
        assign(conn, :section, section)

      false ->
        conn
        |> send_resp(403, "Forbidden")
        |> halt()
    end
  end

  defp available_brands() do
    Branding.list_brands()
    |> Enum.map(fn brand -> {brand.name, brand.id} end)
  end

  defp source_info(source_id) do
    case source_id do
      "product:" <> id ->
        {Sections.get_section!(String.to_integer(id)), "Source Template", :product_slug}

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
      utc_start_date = FormatDateTime.datestring_to_utc_datetime(start_date, conn.assigns.ctx)
      utc_end_date = FormatDateTime.datestring_to_utc_datetime(end_date, conn.assigns.ctx)

      section_params =
        to_atom_keys(section_params)
        |> Map.merge(%{
          blueprint_id: blueprint.id,
          type: :enrollable,
          open_and_free: true,
          context_id: UUID.uuid4(),
          start_date: utc_start_date,
          end_date: utc_end_date,
          page_prompt_template: Oli.Conversation.DefaultPrompts.get_prompt("page_prompt"),
          analytics_version: :v2
        })

      case create_from_product(conn, blueprint, section_params) do
        {:ok, section} ->
          conn
          |> redirect(
            to:
              Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.OverviewView, section.slug,
                section_created: true
              )
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
         %{id: project_id} <- Course.get_project_by_slug(project_slug),
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
        |> Map.put(
          "page_prompt_template",
          Oli.Conversation.DefaultPrompts.get_prompt("page_prompt")
        )
        |> Map.put("analytics_version", :v2)

      case create_from_publication(conn, publication, section_params) do
        {:ok, section} ->
          conn
          |> redirect(
            to:
              Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.OverviewView, section.slug,
                section_created: true
              )
          )

        {:error, error} ->
          changeset =
            case error do
              %Ecto.Changeset{} = changeset ->
                changeset

              _ ->
                Sections.change_independent_learner_section(%Section{})
                |> Ecto.Changeset.add_error(:title, "invalid settings")
            end

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

  def show(conn, _params) do
    section =
      conn.assigns.section
      |> Sections.localize_section_start_end_datetimes(conn.assigns.ctx)

    render(conn, "show.html",
      section: section,
      updates: Sections.check_for_available_publication_updates(section)
    )
  end

  def edit(conn, _params) do
    section =
      conn.assigns.section
      |> Sections.localize_section_start_end_datetimes(conn.assigns.ctx)

    render(conn, "edit.html",
      section: section,
      changeset: Sections.change_section(section),
      available_brands: available_brands()
    )
  end

  # The fields the edit form (`form.html.eex`) renders.
  @edit_form_fields [
    :title,
    :start_date,
    :end_date,
    :brand_id,
    :registration_open,
    :requires_enrollment,
    :skip_email_verification
  ]

  def update(conn, %{
        "section" => %{"start_date" => start_date, "end_date" => end_date} = section_params
      }) do
    section = conn.assigns.section

    utc_start_date = FormatDateTime.datestring_to_utc_datetime(start_date, conn.assigns.ctx)
    utc_end_date = FormatDateTime.datestring_to_utc_datetime(end_date, conn.assigns.ctx)

    section_params =
      section_params
      |> Map.put("start_date", utc_start_date)
      |> Map.put("end_date", utc_end_date)

    case SectionsAudited.update_section_settings(
           audit_context(conn),
           section,
           section_params,
           @edit_form_fields
         ) do
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

      {:error, _reason} ->
        conn
        |> put_flash(:error, "The section could not be updated.")
        |> render("edit.html",
          section: section,
          changeset: Sections.change_section(section),
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
    SectionsAudited.create_section_from_product(audit_context(conn), blueprint, section_params,
      enroll: conn.assigns.current_user
    )
  end

  defp create_from_publication(conn, publication, section_params) do
    SectionsAudited.create_section_from_publication(
      audit_context(conn),
      publication,
      section_params,
      rebuild: true,
      enroll: conn.assigns.current_user,
      post_processing: :all
    )
  end

  # Router plugs handle user auth: an independent instructor acts as the user; otherwise the
  # signed-in author acts.
  defp audit_context(conn),
    do: Context.for_actor(conn.assigns.current_user || conn.assigns.current_author, source: :api)
end
