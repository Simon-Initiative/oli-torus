defmodule OliWeb.Workspaces.CourseAuthor.LandingPageLive do
  use OliWeb, :live_view

  alias Oli.Authoring.Editing.{ContainerEditor, ObjectiveEditor, BankEditor}
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Resources.{ResourceType, Revision}
  alias Oli.Publishing.PublishedResource
  alias Oli.Accounts.Author
  alias Oli.Repo
  alias OliWeb.Common.FormatDateTime
  import Ecto.Query

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    %{project: project, ctx: ctx} = socket.assigns

    # Get objectives count
    objectives_count = count_objectives(project)

    # Get curriculum stats (containers and pages)
    {containers_count, pages_count} = count_curriculum_items(project)

    # Get activity bank count
    activities_count = count_activities(project, ctx.author)

    # Get recent activity
    recent_activity = get_recent_activity(project)

    {:ok,
     assign(socket,
       ctx: ctx,
       project: project,
       objectives_count: objectives_count,
       containers_count: containers_count,
       pages_count: pages_count,
       activities_count: activities_count,
       recent_activity: recent_activity,
       resource_title: project.title,
       resource_slug: project.slug
     )}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="landing-page">
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <!-- Learning Objectives Card -->
        <div class="bg-white border border-gray-200 rounded-lg shadow-sm hover:shadow-md transition-shadow duration-200">
          <div class="p-6">
            <div class="flex items-center justify-between mb-3">
              <h3 class="text-lg font-semibold text-gray-900">Learning Objectives</h3>
              <div class="flex items-center justify-center w-10 h-10 bg-blue-100 rounded-full">
                <svg
                  class="w-5 h-5 text-blue-600"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                  >
                  </path>
                </svg>
              </div>
            </div>
            <p class="text-sm text-gray-600 mb-4">
              {objectives_card_description(@objectives_count)}
            </p>
            <.link
              navigate={~p"/workspaces/course_author/#{@project.slug}/objectives"}
              class="inline-flex items-center px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700 transition-colors duration-200"
            >
              {objectives_button_text(@objectives_count)}
              <svg class="ml-2 w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7">
                </path>
              </svg>
            </.link>
            <%= if @objectives_count > 0 do %>
              <div class="mt-3 text-xs text-gray-500">
                {@objectives_count} {if @objectives_count == 1, do: "objective", else: "objectives"} defined
              </div>
            <% end %>
          </div>
        </div>

    <!-- Curriculum Card -->
        <div class="bg-white border border-gray-200 rounded-lg shadow-sm hover:shadow-md transition-shadow duration-200">
          <div class="p-6">
            <div class="flex items-center justify-between mb-3">
              <h3 class="text-lg font-semibold text-gray-900">Curriculum</h3>
              <div class="flex items-center justify-center w-10 h-10 bg-green-100 rounded-full">
                <svg
                  class="w-5 h-5 text-green-600"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 17V7m0 10a2 2 0 01-2 2H5a2 2 0 01-2-2V7a2 2 0 012-2h2a2 2 0 012 2m0 10a2 2 0 002 2h2a2 2 0 002-2M9 7a2 2 0 012-2h2a2 2 0 012 2m0 10V7m0 10a2 2 0 002 2h2a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2h2a2 2 0 002-2z"
                  >
                  </path>
                </svg>
              </div>
            </div>
            <p class="text-sm text-gray-600 mb-4">
              {curriculum_card_description(@containers_count, @pages_count)}
            </p>
            <.link
              navigate={~p"/workspaces/course_author/#{@project.slug}/curriculum"}
              class="inline-flex items-center px-4 py-2 bg-green-600 text-white text-sm font-medium rounded-md hover:bg-green-700 transition-colors duration-200"
            >
              {curriculum_button_text(@containers_count, @pages_count)}
              <svg class="ml-2 w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7">
                </path>
              </svg>
            </.link>
            <%= if @containers_count > 0 or @pages_count > 0 do %>
              <div class="mt-3 text-xs text-gray-500">
                {curriculum_stats_text(@containers_count, @pages_count)}
              </div>
            <% end %>
          </div>
        </div>

    <!-- Activity Bank Card -->
        <div class="bg-white border border-gray-200 rounded-lg shadow-sm hover:shadow-md transition-shadow duration-200">
          <div class="p-6">
            <div class="flex items-center justify-between mb-3">
              <h3 class="text-lg font-semibold text-gray-900">Activity Bank</h3>
              <div class="flex items-center justify-center w-10 h-10 bg-purple-100 rounded-full">
                <svg
                  class="w-5 h-5 text-purple-600"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"
                  >
                  </path>
                </svg>
              </div>
            </div>
            <p class="text-sm text-gray-600 mb-4">
              {activity_bank_card_description(@activities_count)}
            </p>
            <.link
              navigate={~p"/workspaces/course_author/#{@project.slug}/activity_bank"}
              class="inline-flex items-center px-4 py-2 bg-purple-600 text-white text-sm font-medium rounded-md hover:bg-purple-700 transition-colors duration-200"
            >
              {activity_bank_button_text(@activities_count)}
              <svg class="ml-2 w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7">
                </path>
              </svg>
            </.link>
            <%= if @activities_count > 0 do %>
              <div class="mt-3 text-xs text-gray-500">
                {@activities_count} {if @activities_count == 1, do: "activity", else: "activities"} available
              </div>
            <% end %>
          </div>
        </div>

    <!-- Recent Activity Card -->
        <div class="bg-white border border-gray-200 rounded-lg shadow-sm hover:shadow-md transition-shadow duration-200">
          <div class="p-6">
            <div class="flex items-center justify-between mb-3">
              <h3 class="text-lg font-semibold text-gray-900">Recent Activity</h3>
              <div class="flex items-center justify-center w-10 h-10 bg-orange-100 rounded-full">
                <svg
                  class="w-5 h-5 text-orange-600"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                  >
                  </path>
                </svg>
              </div>
            </div>
            <p class="text-sm text-gray-600 mb-4">
              Track the latest changes made to your course pages
            </p>
            <%= if length(@recent_activity) == 0 do %>
              <p class="text-sm text-gray-500 italic">No recent page edits</p>
            <% else %>
              <div class="space-y-3">
                <%= for activity <- @recent_activity do %>
                  <div class="text-sm">
                    <div class="mb-1">
                      <span class="text-gray-700">{String.trim(activity.author_name)} edited </span>
                      <.link
                        navigate={
                          ~p"/workspaces/course_author/#{@project.slug}/curriculum/#{activity.revision_slug}/edit"
                        }
                        class="text-blue-600 hover:text-blue-800 hover:underline font-medium"
                      >
                        {truncate_title(activity.title, 35)}
                      </.link>
                    </div>
                    <div class="text-gray-500 text-xs">
                      {format_relative_time(activity.updated_at, @ctx)}
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </div>

    <!-- Quick Actions Section -->
      <div class="mt-8 bg-gray-50 border border-gray-200 rounded-lg">
        <div class="p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Quick Actions</h3>
          <div class="flex flex-wrap gap-3">
            <.link
              navigate={~p"/workspaces/course_author/#{@project.slug}/overview"}
              class="inline-flex items-center px-3 py-2 bg-gray-100 text-gray-700 text-sm rounded-md hover:bg-gray-200 transition-colors duration-200"
            >
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"></path>
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>
              </svg>
              Settings
            </.link>
            <.link
              navigate={~p"/workspaces/course_author/#{@project.slug}/publish"}
              class="inline-flex items-center px-3 py-2 bg-gray-100 text-gray-700 text-sm rounded-md hover:bg-gray-200 transition-colors duration-200"
            >
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12"></path>
              </svg>
              Publish
            </.link>
            <.link
              navigate={~p"/workspaces/course_author/#{@project.slug}/insights"}
              class="inline-flex items-center px-3 py-2 bg-gray-100 text-gray-700 text-sm rounded-md hover:bg-gray-200 transition-colors duration-200"
            >
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"></path>
              </svg>
              Insights
            </.link>

          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions for dynamic content
  defp count_objectives(project) do
    project
    |> ObjectiveEditor.fetch_objective_mappings()
    |> length()
  end

  defp count_curriculum_items(project) do
    project_slug = project.slug
    root_container = AuthoringResolver.root_container(project_slug)
    children = ContainerEditor.list_all_container_children(root_container, project)

    container_type_id = ResourceType.get_id_by_type("container")
    page_type_id = ResourceType.get_id_by_type("page")

    containers_count =
      children
      |> Enum.count(fn child -> child.resource_type_id == container_type_id end)

    pages_count =
      children
      |> Enum.count(fn child -> child.resource_type_id == page_type_id end)

    {containers_count, pages_count}
  end

  defp objectives_card_description(0) do
    "Get started here by authoring some initial learning objectives for your course. Learning objectives help define what students should achieve."
  end

  defp objectives_card_description(count) do
    "Define and manage learning objectives for your course (#{count} total). Review and update your learning outcomes."
  end

  defp objectives_button_text(0), do: "Create Learning Objectives"
  defp objectives_button_text(_count), do: "Manage Objectives"

  defp curriculum_card_description(0, 0) do
    "Create your course structure by organizing content into units and pages. Start building your curriculum here."
  end

  defp curriculum_card_description(containers, pages) do
    container_text = if containers == 1, do: "unit", else: "units"
    page_text = if pages == 1, do: "page", else: "pages"

    "Define your course structure (#{containers} #{container_text}, #{pages} total #{page_text}). Organize and manage your curriculum."
  end

  defp curriculum_button_text(0, 0), do: "Build Curriculum"
  defp curriculum_button_text(_containers, _pages), do: "Manage Curriculum"

  defp curriculum_stats_text(containers, pages) do
    container_text = if containers == 1, do: "unit", else: "units"
    page_text = if pages == 1, do: "page", else: "pages"
    "#{containers} #{container_text}, #{pages} #{page_text}"
  end

  defp count_activities(project, author) do
    case BankEditor.create_context(project.slug, author) do
      {:ok, context} -> context.totalCount
      _ -> 0
    end
  end

  defp get_recent_activity(project) do
    page_type_id = ResourceType.get_id_by_type("page")

    from(pr in PublishedResource,
      join: r in Revision,
      on: pr.revision_id == r.id,
      join: a in Author,
      on: r.author_id == a.id,
      where:
        pr.publication_id in subquery(project_working_publication(project.slug)) and
          r.resource_type_id == ^page_type_id and
          not r.deleted,
      order_by: [desc: r.updated_at],
      limit: 5,
      select: %{
        revision_slug: r.slug,
        title: r.title,
        author_name:
          fragment("COALESCE(?, '') || ' ' || COALESCE(?, '')", a.given_name, a.family_name),
        updated_at: r.updated_at
      }
    )
    |> Repo.all()
  end

  defp project_working_publication(project_slug) do
    from(p in Oli.Publishing.Publications.Publication,
      join: c in Oli.Authoring.Course.Project,
      on: p.project_id == c.id,
      where: c.slug == ^project_slug and is_nil(p.published),
      select: p.id
    )
  end

  defp activity_bank_card_description(0) do
    "Create and manage reusable activities for your course. The Activity Bank lets you build a library of questions and activities that can be used across multiple pages."
  end

  defp activity_bank_card_description(count) do
    "Manage your collection of reusable activities (#{count} available). Create, edit, and organize questions that can be used throughout your course."
  end

  defp activity_bank_button_text(0), do: "Start Building Activities"
  defp activity_bank_button_text(_count), do: "Manage Activity Bank"

  defp truncate_title(title, max_length) do
    if String.length(title) <= max_length do
      title
    else
      String.slice(title, 0, max_length) <> "..."
    end
  end

  defp format_relative_time(datetime, ctx) do
    FormatDateTime.date(datetime, ctx: ctx, precision: :relative)
  end
end
