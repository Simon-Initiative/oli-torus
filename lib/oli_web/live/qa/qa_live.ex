defmodule OliWeb.Qa.QaLive do
  @moduledoc """
  LiveView implementation of QA view.
  """
  use OliWeb, :live_view

  import Phoenix.HTML.Link

  alias OliWeb.Common.{SessionContext, Utils}
  alias Oli.Authoring.Course
  alias Oli.Qa
  alias OliWeb.Qa.WarningFilter
  alias OliWeb.Qa.WarningSummary
  alias OliWeb.Qa.WarningDetails
  alias OliWeb.Qa.State
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Repo
  alias Oli.Authoring.Broadcaster.Subscriber

  def mount(
        %{"project_id" => project_slug},
        %{"current_author_id" => _} = session,
        socket
      ) do
    ctx = SessionContext.init(socket, session)
    project = Course.get_project_by_slug(project_slug)

    subscribe(project.slug)

    {:ok,
     assign(
       socket,
       State.initialize_state(ctx, project, read_current_review(project))
     )}
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
      Enum.map(warnings, fn w -> w.revision end)
      |> Enum.filter(fn r ->
        r.resource_type_id == Oli.Resources.ResourceType.id_for_activity()
      end)
      |> Enum.map(fn r -> r.resource_id end)
      |> Oli.Publishing.determine_parent_pages(
        Oli.Publishing.project_working_publication(project.slug).id
      )

    {warnings, parent_pages, qa_reviews}
  end

  def handle_event("dismiss", _, socket) do
    warning_id = socket.assigns.selected.id

    socket =
      case Qa.Warnings.dismiss_warning(warning_id) do
        {:ok, _} ->
          Oli.Authoring.Broadcaster.broadcast_dismiss_warning(
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
    state = socket.assigns
    filters = State.toggle_filter(state, type)

    selected_id =
      if state.selected == nil do
        ""
      else
        state.selected.id
      end

    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Qa.QaLive,
           state.project.slug,
           State.to_params(filters, selected_id)
         ),
       replace: true
     )}
  end

  def handle_event("select", %{"warning" => warning_id}, socket) do
    filters = socket.assigns.filters

    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Qa.QaLive,
           socket.assigns.project.slug,
           State.to_params(filters, warning_id)
         ),
       replace: true
     )}
  end

  def handle_event("review", _, socket) do
    project = socket.assigns.project
    Qa.review_project(project.slug)
    Oli.Authoring.Broadcaster.broadcast_review(socket.assigns.project.slug)

    {:noreply, socket}
  end

  def handle_event("keydown", %{"warning" => warning_id, "key" => key}, socket) do
    case key do
      "Enter" -> handle_event("select", %{"warning" => warning_id}, socket)
      _ -> {:noreply, socket}
    end
  end

  def handle_params(params, _, socket) do
    {:noreply, assign(socket, State.from_params(socket.assigns, params))}
  end

  def render(assigns) do
    ~H"""
    <div class="container review">
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

          <%= link to: Routes.resource_path(OliWeb.Endpoint, :preview, @project.slug), class: "btn btn-outline-primary mt-3 ml-2", target: "preview-#{@project.slug}" do %>
            Preview Course <i class="fas fa-external-link-alt ml-1"></i>
          <% end %>
        </div>
      </div>

      <%= if !Enum.empty?(@qa_reviews) do %>
        <div class="grid grid-cols-12 mt-4">
          <div class="col-span-12">
            <p class="mb-3">
              Last reviewed <strong><%= Utils.render_date(hd(@qa_reviews), :inserted_at, @ctx) %></strong>,
              with <strong><%= length(@warnings) %></strong>
              potential improvement <%= if length(@warnings) == 1 do
                "opportunity"
              else
                "opportunities"
              end %> found.
            </p>
            <%= if !Enum.empty?(@warnings_by_type) do %>
              <div class="d-flex">
                <%= for type <- @warning_types do %>
                  <.live_component
                    module={WarningFilter}
                    active={MapSet.member?(@filters, type)}
                    type={type}
                    warnings={Map.get(@warnings_by_type, type)}
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
    warning = Oli.Qa.Warnings.get_warning!(warning_id) |> Repo.preload([:review, :revision])
    {:noreply, assign(socket, State.warning_arrived(socket.assigns, warning))}
  end
end
