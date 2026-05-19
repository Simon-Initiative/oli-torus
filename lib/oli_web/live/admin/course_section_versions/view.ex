defmodule OliWeb.Admin.CourseSectionVersions.View do
  use OliWeb, :live_view

  alias OliWeb.Admin.CourseSectionVersions.Queries
  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Common.Utils

  require Logger

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  @default_sort_by "title"
  @default_sort_dir :asc
  @no_end_date_sort_value -9_999_999_999_999

  def mount(params, _session, socket) do
    project_slug = params["project_id"] || params["project_slug"]

    assigns =
      case safe_load(project_slug) do
        {:ok, matrix} ->
          [
            breadcrumbs: breadcrumbs(matrix.source),
            error: nil,
            matrix: sort_matrix(matrix, @default_sort_by, @default_sort_dir),
            page_title: page_title(matrix),
            sort_by: @default_sort_by,
            sort_dir: @default_sort_dir,
            project_slug: project_slug
          ]

        {:error, reason} ->
          [
            breadcrumbs: breadcrumbs(nil),
            error: error_message(reason),
            matrix: nil,
            page_title: "Full Versioning Details",
            sort_by: @default_sort_by,
            sort_dir: @default_sort_dir,
            project_slug: project_slug
          ]
      end

    {:ok, assign(socket, assigns)}
  end

  attr(:breadcrumbs, :any)
  attr(:ctx, :any)
  attr(:error, :string, default: nil)
  attr(:matrix, :map, default: nil)
  attr(:page_title, :string)
  attr(:project_slug, :string)
  attr(:sort_by, :string)
  attr(:sort_dir, :atom)

  def render(assigns) do
    ~H"""
    <div class="px-6 py-4">
      <div class="mb-5">
        <h1 class="text-2xl font-bold text-[#353740] dark:text-[#EEEBF5] leading-loose">
          {@page_title}
        </h1>
        <p class="text-sm text-[#6B7280] dark:text-[#C7C3CC]">
          Source Project: {@project_slug}
        </p>
      </div>

      <%= if @error do %>
        <div class="alert alert-warning" role="alert">
          {@error}
        </div>
      <% else %>
        <div class="flex flex-row gap-6 mb-4 text-sm text-[#353740] dark:text-[#EEEBF5]">
          <div>
            <span class="font-semibold">Active sections / templates:</span>
            {length(@matrix.sections)}
          </div>
          <div>
            <span class="font-semibold">Material sources:</span>
            {length(@matrix.projects)}
          </div>
        </div>

        <div class="mb-4 rounded border border-[#CED1D9] bg-[#F8F9FA] p-4 text-sm text-[#353740] dark:border-[#3B3740] dark:bg-[#222126] dark:text-[#EEEBF5]">
          <p class="mb-3">
            The table below shows complete utilization of this course project across active course sections and templates where this project is used as the base project or remixed in as source material.
          </p>
          <div class="flex flex-wrap items-center gap-x-5 gap-y-2">
            <span class="font-semibold">Legend:</span>
            <span class="inline-flex items-center gap-2">
              <span class="badge badge-primary">v1.0.0</span> Latest version
            </span>
            <span class="inline-flex items-center gap-2">
              <span class="badge badge-danger">v1.0.0</span> Newer version available
            </span>
            <span class="inline-flex items-center gap-2">
              <span class="badge badge-light text-muted">N/A</span> Not in use
            </span>
            <span class="inline-flex items-center gap-2">
              <span class="text-xs text-muted">(base project)</span> Row base project
            </span>
          </div>
        </div>

        <div class="overflow-x-auto border border-[#CED1D9] dark:border-[#3B3740]">
          <table class="table table-striped mb-0 min-w-full">
            <thead>
              <tr>
                <th class="relative align-bottom whitespace-nowrap min-w-[280px]">
                  <button
                    type="button"
                    class="absolute inset-0 h-full w-full cursor-pointer border-0 bg-transparent p-0"
                    phx-click="sort"
                    phx-value-sort_by="title"
                    aria-label="Sort by course section or template title"
                  >
                  </button>
                  <div class="relative pointer-events-none">
                    Course Section / Template
                    <.sort_indicator sort_by={@sort_by} sort_dir={@sort_dir} sort_key="title" />
                  </div>
                </th>
                <th class="relative align-bottom whitespace-nowrap min-w-[170px]">
                  <button
                    type="button"
                    class="absolute inset-0 h-full w-full cursor-pointer border-0 bg-transparent p-0"
                    phx-click="sort"
                    phx-value-sort_by="end_date"
                    aria-label="Sort by end date"
                  >
                  </button>
                  <div class="relative pointer-events-none">
                    End Date
                    <.sort_indicator sort_by={@sort_by} sort_dir={@sort_dir} sort_key="end_date" />
                  </div>
                </th>
                <th
                  :for={project <- @matrix.projects}
                  class="relative align-bottom whitespace-nowrap min-w-[220px]"
                >
                  <button
                    type="button"
                    class="absolute inset-0 h-full w-full cursor-pointer border-0 bg-transparent p-0"
                    phx-click="sort"
                    phx-value-sort_by={project_sort_key(project)}
                    aria-label={"Sort by #{project.title} version"}
                  >
                  </button>
                  <div class="relative pointer-events-none flex flex-col">
                    <a
                      class="pointer-events-auto text-Text-text-link font-semibold"
                      href={~p"/workspaces/course_author/#{project.slug}/overview"}
                    >
                      {project.title}
                      <.sort_indicator
                        sort_by={@sort_by}
                        sort_dir={@sort_dir}
                        sort_key={project_sort_key(project)}
                      />
                    </a>
                    <span class="text-xs font-normal text-[#6B7280] dark:text-[#C7C3CC]">
                      {project.slug}
                    </span>
                    <span
                      :if={project.latest_publication}
                      class="badge badge-pill badge-primary mt-1 w-fit"
                    >
                      {render_version(project.latest_publication)}
                    </span>
                  </div>
                </th>
              </tr>
            </thead>
            <tbody>
              <%= if Enum.empty?(@matrix.sections) do %>
                <tr>
                  <td colspan={2 + length(@matrix.projects)} class="text-center py-5">
                    No active course sections or templates found.
                  </td>
                </tr>
              <% end %>
              <tr :for={section <- @matrix.sections}>
                <td class="align-middle">
                  <div class="flex flex-col">
                    <a
                      class="text-Text-text-link font-semibold"
                      href={~p"/sections/#{section.slug}/manage"}
                    >
                      {section.title}
                    </a>
                    <span class="text-xs font-semibold uppercase text-[#6B7280] dark:text-[#C7C3CC]">
                      {row_type_label(section)}
                    </span>
                    <span class="text-xs text-[#6B7280] dark:text-[#C7C3CC]">
                      {section.slug}
                    </span>
                  </div>
                </td>
                <td class="align-middle whitespace-nowrap">
                  {render_end_date(section, @ctx)}
                </td>
                <td :for={project <- @matrix.projects} class="align-middle whitespace-nowrap">
                  <div class="flex flex-col items-start gap-1">
                    <.version_badge section={section} project={project} />
                    <span :if={base_project?(section, project)} class="text-xs text-muted">
                      (base project)
                    </span>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end

  def handle_event("sort", %{"sort_by" => sort_by}, socket) do
    case normalize_sort_by(sort_by, socket.assigns.matrix) do
      {:ok, sort_by} ->
        sort_dir = next_sort_dir(socket.assigns.sort_by, socket.assigns.sort_dir, sort_by)

        socket =
          assign(socket,
            matrix: sort_matrix(socket.assigns.matrix, sort_by, sort_dir),
            sort_by: sort_by,
            sort_dir: sort_dir
          )

        {:noreply, socket}

      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("sort", _params, socket), do: {:noreply, socket}

  defp breadcrumbs(%{slug: slug}) do
    [
      Breadcrumb.new(%{
        full_title: "Project Overview",
        link: ~p"/workspaces/course_author/#{slug}/overview"
      }),
      Breadcrumb.new(%{full_title: "Full Versioning Details"})
    ]
  end

  defp breadcrumbs(_), do: [Breadcrumb.new(%{full_title: "Full Versioning Details"})]

  defp safe_load(project_slug) do
    Queries.load(project_slug)
  rescue
    exception ->
      Logger.error("""
      Failed to load full versioning details.
      project_slug=#{inspect(project_slug)}
      exception=#{Exception.format(:error, exception, __STACKTRACE__)}
      """)

      {:error, :load_failed}
  catch
    kind, reason ->
      Logger.error("""
      Failed to load full versioning details.
      project_slug=#{inspect(project_slug)}
      #{kind}=#{inspect(reason)}
      """)

      {:error, :load_failed}
  end

  defp page_title(%{source: source}),
    do: "Full Versioning Details for #{source.title}"

  defp error_message(:not_found), do: "No matching project was found."
  defp error_message(_), do: "Unable to load full versioning details."

  defp render_end_date(%{end_date: nil}, _ctx), do: "No end date"

  defp render_end_date(section, ctx) do
    Utils.render_date_with_opts(section, :end_date,
      ctx: ctx,
      precision: :date,
      show_timezone: false
    )
  end

  defp row_type_label(%{type: :blueprint}), do: "Template"
  defp row_type_label(%{type: "blueprint"}), do: "Template"
  defp row_type_label(%{type: :enrollable}), do: "Section"
  defp row_type_label(%{type: "enrollable"}), do: "Section"
  defp row_type_label(_), do: "Section"

  defp base_project?(%{base_project_id: base_project_id}, %{id: project_id}),
    do: base_project_id == project_id

  defp base_project?(_, _), do: false

  attr(:sort_by, :string, required: true)
  attr(:sort_dir, :atom, required: true)
  attr(:sort_key, :string, required: true)

  defp sort_indicator(assigns) do
    ~H"""
    <span :if={@sort_by == @sort_key} class="ml-1" aria-hidden="true">
      <%= if @sort_dir == :asc do %>
        &uarr;
      <% else %>
        &darr;
      <% end %>
    </span>
    """
  end

  attr(:section, :map, required: true)
  attr(:project, :map, required: true)

  defp version_badge(assigns) do
    version = Map.get(assigns.section.publications_by_project_id, assigns.project.id)

    assigns =
      assigns
      |> assign(:version, version)
      |> assign(:version_label, render_version(version))
      |> assign(
        :version_badge_class,
        version_badge_class(version, assigns.project.latest_publication_id)
      )

    ~H"""
    <span class={@version_badge_class}>
      {@version_label}
    </span>
    """
  end

  defp render_version(%{edition: edition, major: major, minor: minor}) do
    Utils.render_version(version_part(edition), version_part(major), version_part(minor))
  end

  defp render_version(_), do: "N/A"

  defp outdated?(%{publication_id: publication_id}, latest_publication_id)
       when not is_nil(latest_publication_id) do
    publication_id != latest_publication_id
  end

  defp outdated?(_, _), do: false

  defp version_badge_class(nil, _latest_publication_id), do: "badge badge-light text-muted"

  defp version_badge_class(version, latest_publication_id) do
    if outdated?(version, latest_publication_id),
      do: "badge badge-danger",
      else: "badge badge-primary"
  end

  defp next_sort_dir(current_sort_by, current_sort_dir, sort_by) do
    case {current_sort_by, current_sort_dir} do
      {^sort_by, :asc} -> :desc
      {^sort_by, :desc} -> :asc
      _ -> :asc
    end
  end

  defp sort_matrix(nil, _sort_by, _sort_dir), do: nil

  defp sort_matrix(matrix, sort_by, sort_dir) do
    Map.update(matrix, :sections, [], &sort_sections(&1, sort_by, sort_dir))
  end

  defp sort_sections(sections, sort_by, sort_dir) do
    Enum.sort(sections, fn section_a, section_b ->
      compare_sections(section_a, section_b, sort_by, sort_dir)
    end)
  end

  defp compare_sections(section_a, section_b, sort_by, sort_dir) do
    value_a = sort_value(section_a, sort_by)
    value_b = sort_value(section_b, sort_by)

    cond do
      is_nil(value_a) and is_nil(value_b) ->
        section_title(section_a) <= section_title(section_b)

      is_nil(value_a) ->
        false

      is_nil(value_b) ->
        true

      value_a == value_b ->
        section_title(section_a) <= section_title(section_b)

      sort_dir == :desc ->
        value_a > value_b

      true ->
        value_a < value_b
    end
  end

  defp sort_value(section, "title"), do: section_title(section)

  defp sort_value(%{end_date: nil}, "end_date"), do: @no_end_date_sort_value

  defp sort_value(%{end_date: %DateTime{} = end_date}, "end_date"),
    do: DateTime.to_unix(end_date, :second)

  defp sort_value(%{end_date: %NaiveDateTime{} = end_date}, "end_date") do
    end_date
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_unix(:second)
  end

  defp sort_value(%{end_date: %Date{} = end_date}, "end_date"),
    do: Date.to_gregorian_days(end_date)

  defp sort_value(section, "project:" <> project_id) do
    case Integer.parse(project_id) do
      {project_id, ""} -> sort_project_version(section, project_id)
      _ -> sort_value(section, "title")
    end
  end

  defp sort_value(section, _), do: section_title(section)

  defp sort_project_version(section, project_id) do
    case Map.get(Map.get(section, :publications_by_project_id, %{}), project_id) do
      nil -> {0, 0, 0}
      %{edition: edition, major: major, minor: minor} -> version_tuple(edition, major, minor)
      _ -> {0, 0, 0}
    end
  end

  defp section_title(section), do: String.downcase(section.title || "")

  defp project_sort_key(project), do: "project:#{project.id}"

  defp normalize_sort_by(sort_by, %{projects: projects})
       when sort_by in ["title", "end_date"] and is_list(projects),
       do: {:ok, sort_by}

  defp normalize_sort_by("project:" <> project_id = sort_by, %{projects: projects})
       when is_list(projects) do
    with {project_id, ""} <- Integer.parse(project_id),
         true <- Enum.any?(projects, &(&1.id == project_id)) do
      {:ok, sort_by}
    else
      _ -> :error
    end
  end

  defp normalize_sort_by(_sort_by, _matrix), do: :error

  defp version_tuple(edition, major, minor),
    do: {version_part(edition), version_part(major), version_part(minor)}

  defp version_part(value) when is_integer(value), do: value

  defp version_part(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _ -> 0
    end
  end

  defp version_part(_), do: 0
end
