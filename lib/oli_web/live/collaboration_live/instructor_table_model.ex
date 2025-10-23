defmodule OliWeb.CollaborationLive.InstructorTableModel do
  use Phoenix.Component

  alias OliWeb.CollaborationLive.AdminTableModel
  alias OliWeb.Common.Table.{ColumnSpec, Common, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.FormatDateTime

  def new(rows, ctx, opts \\ [is_listing: true]) do
    column_specs =
      case opts[:is_listing] do
        true ->
          [
            %ColumnSpec{
              name: :page_title,
              label: "Page Title",
              render_fn: &__MODULE__.render_page_title/3,
              sort_fn: &AdminTableModel.custom_sort/2
            },
            %ColumnSpec{
              name: :status,
              label: "Status",
              render_fn: &AdminTableModel.render_status/3,
              sort_fn: &AdminTableModel.custom_sort/2
            },
            %ColumnSpec{
              name: :number_of_posts,
              label: "# of Posts"
            },
            %ColumnSpec{
              name: :number_of_posts_pending_approval,
              label: "# of Posts Pending Approval"
            },
            %ColumnSpec{
              name: :most_recent_post,
              label: "Most Recent Post",
              render_fn: &Common.render_date/3,
              sort_fn: &Common.sort_date/2
            }
          ]

        false ->
          [
            %ColumnSpec{
              name: :page_title,
              label: "Page Title",
              render_fn: &__MODULE__.render_collab_space/3,
              th_class: "hidden",
              td_class: "!border-r-0 border-l-0"
            }
          ]
      end

    SortableTableModel.new(
      rows: rows,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id],
      data: %{
        ctx: ctx
      }
    )
  end

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end

  def render_collab_space(
        %{ctx: _ctx} = assigns,
        %{
          page: %{title: title, slug: page_revision_slug},
          section: %{slug: section_slug},
          collab_space_config: %{"status" => status},
          most_recent_post: most_recent_post,
          number_of_posts: number_of_posts,
          number_of_posts_pending_approval: number_of_posts_pending_approval
        },
        _spec
      ) do
    assigns =
      Map.merge(assigns, %{
        title: title,
        status: status,
        most_recent_post: most_recent_post,
        number_of_posts: number_of_posts,
        number_of_posts_pending_approval: number_of_posts_pending_approval,
        section_slug: section_slug,
        page_revision_slug: page_revision_slug
      })

    ~H"""
    <div class="flex flex-col px-10 py-5">
      <div class="flex justify-between mb-3">
        <div class="flex gap-2">
          <span class="torus-span">{@title}</span>
          <span class={"font-normal text-white text-xs uppercase badge
                                badge-#{case @status do
            "enabled" -> "success"
            "disabled" -> "secondary"
            _ -> "info"
          end}"}>
            {@status}
          </span>
        </div>
        <span :if={@most_recent_post} class="torus-span">
          {"Most recent post: #{FormatDateTime.date(@most_recent_post, @ctx)}"}
        </span>
      </div>
      <div class="flex justify-between">
        <p class="torus-p">
          <%= if @number_of_posts == 0 do %>
            No posts yet
          <% else %>
            Number of posts: <b>{@number_of_posts}</b>
            <%= if @number_of_posts_pending_approval > 0 do %>
              {"(#{@number_of_posts_pending_approval} pending approval)"}
            <% end %>
          <% end %>
        </p>
        <.link
          href={
            Routes.page_delivery_path(
              OliWeb.Endpoint,
              :page_preview,
              @section_slug,
              @page_revision_slug
            )
          }
          class="torus-button primary"
        >
          View
        </.link>
      </div>
    </div>
    """
  end

  def render_page_title(
        assigns,
        %{page: %{title: title, slug: page_revision_slug}, section: %{slug: section_slug}},
        _
      ) do
    route_path =
      Routes.page_delivery_path(OliWeb.Endpoint, :page_preview, section_slug, page_revision_slug)

    SortableTableModel.render_link_column(assigns, title, route_path)
  end
end
