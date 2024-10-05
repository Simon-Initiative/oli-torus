defmodule OliWeb.Workspaces.CourseAuthor.ReviewLive do
  use OliWeb, :live_view

  alias Oli.Authoring.Broadcaster
  alias Oli.Authoring.Broadcaster.Subscriber
  alias Oli.{Publishing, Qa, Repo}
  alias Oli.Resources.ResourceType
  alias OliWeb.Common.Utils
  alias OliWeb.Workspaces.CourseAuthor.Qa.{State, WarningFilter, WarningSummary, WarningDetails}

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    %{project: project, ctx: ctx} = socket.assigns

    subscribe(project.slug)

    initial_state =
      Map.merge(State.initialize_state(ctx, project, read_current_review(project)), %{
        resource_slug: project.slug,
        resource_title: project.title
      })

    {:ok,
     assign(
       socket,
       initial_state
     )}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _, socket) do
    {:noreply, assign(socket, State.from_params(socket.assigns, params))}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <h2 id="header_id" class="pb-2">Review</h2>
    <div class="review">
      <div class="grid grid-cols-12">
        <div class="col-span-12">
          <p>
            Run an automated review before publishing to check for broken links and other common issues that may be present in your course.
          </p>

          <button
            class="btn btn-primary mt-3"
            id="button-publish"
            phx-click="review"
            phx-disable-with="Reviewing..."
          >
            Run Review
          </button>

          <.link
            class="btn btn-outline-primary mt-3 ml-2"
            href={~p"/authoring/project/#{@project.slug}/preview"}
            target={"preview-#{@project.slug}"}
          >
            Preview Course <i class="fas fa-external-link-alt ml-1"></i>
          </.link>
        </div>
      </div>

      <%= if !Enum.empty?(@qa_reviews) do %>
        <div class="grid grid-cols-12 mt-4">
          <div class="col-span-12">
            <p class="mb-3">
              Last reviewed <strong><%= Utils.render_date(hd(@qa_reviews), :inserted_at, @ctx) %></strong>,
              with <strong><%= length(@warnings) %></strong>
              potential improvement <%= if length(@warnings) == 1,
                do: "opportunity",
                else: "opportunities" %> found.
            </p>
            <%= if !Enum.empty?(@warnings_by_type) do %>
              <div class="d-flex">
                <%= for type <- @warning_types do %>
                  <.live_component
                    module={WarningFilter}
                    active={MapSet.member?(@filters, type)}
                    type={type}
                    warnings={Map.get(@warnings_by_type, type)}
                    id={"filter-#{type}"}
                  />
                <% end %>
              </div>

              <div class="reviews">
                <ul class="review-links">
                  <WarningSummary.render
                    :for={warning <- @filtered_warnings}
                    warning={warning}
                    selected={@selected}
                  />
                </ul>
                <div class="review-cards">
                  <WarningDetails.render
                    :if={@selected != nil}
                    parent_pages={@parent_pages}
                    selected={@selected}
                    author={@author}
                    project={@project}
                    warning={@selected}
                  />
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # spin up subscriptions for running of reviews and dismissal of warnings
  defp subscribe(project_slug) do
    Subscriber.subscribe_to_new_reviews(project_slug)
    Subscriber.subscribe_to_warning_dismissals(project_slug)
    Subscriber.subscribe_to_warning_new(project_slug)
  end

  def read_current_review(project) do
    warnings = Qa.Warnings.list_active_warnings(project.id)
    qa_reviews = Qa.Reviews.list_reviews(project.id)

    parent_pages =
      warnings
      |> Enum.filter(fn w -> w.revision.resource_type_id == ResourceType.id_for_activity() end)
      |> Enum.map(fn w -> w.revision.resource_id end)
      |> Publishing.determine_parent_pages(
        Publishing.project_working_publication(project.slug).id
      )

    {warnings, parent_pages, qa_reviews}
  end

  @impl Phoenix.LiveView
  def handle_event("dismiss", _, socket) do
    warning_id = socket.assigns.selected.id

    socket =
      case Qa.Warnings.dismiss_warning(warning_id) do
        {:ok, _} ->
          Broadcaster.broadcast_dismiss_warning(
            warning_id,
            socket.assigns.project.slug
          )

          socket

        {:error, _changeset} ->
          socket
          |> put_flash(:error, "Could not dimiss warning")
      end

    {:noreply, socket}
  end

  def handle_event("filter", %{"type" => type}, socket) do
    %{selected: selected, project: project} = assigns = socket.assigns
    filters = State.toggle_filter(assigns, type)

    selected_id =
      if is_nil(selected), do: "", else: selected.id

    params = State.to_params(filters, selected_id)

    {:noreply,
     push_patch(socket,
       to: ~p"/workspaces/course_author/#{project.slug}/review?#{params}",
       replace: true
     )}
  end

  def handle_event("select", %{"warning" => warning_id}, socket) do
    %{filters: filters, project: project} = socket.assigns
    params = State.to_params(filters, warning_id)

    {:noreply,
     push_patch(socket,
       to: ~p"/workspaces/course_author/#{project.slug}/review?#{params}",
       replace: true
     )}
  end

  def handle_event("review", _, socket) do
    project_slug = socket.assigns.project.slug
    Qa.review_project(project_slug)
    Broadcaster.broadcast_review(project_slug)

    {:noreply, socket}
  end

  def handle_event("keydown", %{"warning" => warning_id, "key" => key}, socket) do
    case key do
      "Enter" -> handle_event("select", %{"warning" => warning_id}, socket)
      _ -> {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:new_review, _}, socket) do
    {:noreply,
     assign(
       socket,
       State.new_review_ran(socket.assigns, read_current_review(socket.assigns.project))
     )}
  end

  def handle_info({:dismiss_warning, warning_id, _}, socket) do
    {:noreply, assign(socket, State.warning_dismissed(socket.assigns, warning_id))}
  end

  def handle_info({:new_warning, warning_id, _}, socket) do
    warning = Qa.Warnings.get_warning!(warning_id) |> Repo.preload([:review, :revision])
    {:noreply, assign(socket, State.warning_arrived(socket.assigns, warning))}
  end
end
