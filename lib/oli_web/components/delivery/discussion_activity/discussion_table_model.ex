defmodule OliWeb.Discussion.TableModel do
  use Phoenix.Component

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Common.FormatDateTime
  alias Phoenix.LiveView.JS
  alias OliWeb.Components.Modal
  alias OliWeb.Router.Helpers, as: Routes

  def new(posts, section_slug, target) do
    column_specs = [
      %ColumnSpec{
        name: :id,
        label: nil,
        render_fn: &__MODULE__.render_post/3,
        th_class: "hidden",
        td_class: "!border-r-0 border-l-0"
      }
    ]

    SortableTableModel.new(
      rows: posts,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id],
      data: %{target: target, section_slug: section_slug}
    )
  end

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end

  defp href(section_slug, post) do
    container_type_id = Oli.Resources.ResourceType.id_for_container()

    case post.resource_type_id do
      ^container_type_id ->
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section_slug,
          "reports",
          "course_discussion"
        )

      _ ->
        Routes.page_delivery_path(OliWeb.Endpoint, :page_preview, section_slug, post.slug)
    end
  end

  def render_post(assigns, post, _) do
    assigns = Map.merge(assigns, %{post: post})

    ~H"""
    <div class="flex flex-col px-10 py-5">
      <div class="flex justify-between mb-6">
        <a class="text-delivery-primary hover:text-delivery-primary" href={href(@section_slug, @post)}>
          {@post.title}
        </a>
        <span class="torus-span">
          {FormatDateTime.format_datetime(@post.inserted_at, show_timezone: false)}
        </span>
      </div>
      <div class="flex justify-between gap-2">
        <h6 class="torus-h6 font-extrabold">{@post.user_name}</h6>
        <%= if @post.status == :submitted do %>
          <div class="flex gap-2">
            <button
              class="btn btn-sm btn-success flex items-center gap-2"
              data-toggle="tooltip"
              title="Accept"
              phx-click={
                JS.push("display_accept_modal", target: @target)
                |> Modal.show_modal("accept_post_modal")
              }
              phx-value-post_id={@post.id}
            >
              <span>Approve</span>
              <i class="fa fa-check" />
            </button>

            <button
              class="btn btn-sm btn-danger flex items-center gap-2"
              data-toggle="tooltip"
              title="Reject"
              phx-click={
                JS.push("display_reject_modal", target: @target)
                |> Modal.show_modal("reject_post_modal")
              }
              phx-value-post_id={@post.id}
            >
              <span>Reject</span>
              <i class="fa fa-times" />
            </button>
          </div>
        <% end %>
      </div>
      <p class="torus-p">{@post.content.message}</p>
    </div>
    """
  end
end
