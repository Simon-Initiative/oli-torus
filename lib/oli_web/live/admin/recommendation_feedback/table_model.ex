defmodule OliWeb.Admin.RecommendationFeedback.TableModel do
  use Phoenix.Component

  alias OliWeb.Common.FormatDateTime
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end

  def new(feedback_rows, ctx) do
    SortableTableModel.new(
      rows: feedback_rows,
      column_specs: [
        %ColumnSpec{
          name: :section_slug,
          label: "Section",
          render_fn: &__MODULE__.render_section_column/3
        },
        %ColumnSpec{
          name: :scope_type,
          label: "Scope",
          render_fn: &__MODULE__.render_scope_column/3
        },
        %ColumnSpec{
          name: :user_email,
          label: "Submitted By",
          render_fn: &__MODULE__.render_user_column/3
        },
        %ColumnSpec{
          name: :sentiment,
          label: "Sentiment",
          render_fn: &__MODULE__.render_sentiment_column/3
        },
        %ColumnSpec{
          name: :recommendation_id,
          label: "Recommendation ID",
          render_fn: &__MODULE__.render_recommendation_id_column/3
        },
        %ColumnSpec{
          name: :feedback_text,
          label: "Custom Feedback",
          render_fn: &__MODULE__.render_feedback_text_column/3
        },
        %ColumnSpec{
          name: :inserted_at,
          label: "Submitted At",
          render_fn: &__MODULE__.render_inserted_at_column/3
        }
      ],
      event_suffix: "",
      id_field: [:id],
      data: %{ctx: ctx}
    )
  end

  def render_inserted_at_column(assigns, %{inserted_at: inserted_at}, _) do
    assigns = Map.put(assigns, :inserted_at, inserted_at)

    ~H"""
    <div class="text-sm whitespace-nowrap">
      {FormatDateTime.format_datetime(@inserted_at, show_timezone: true)}
    </div>
    """
  end

  def render_section_column(assigns, %{section_title: title, section_slug: slug}, _) do
    assigns = Map.merge(assigns, %{title: title, slug: slug})

    ~H"""
    <div class="text-sm">
      <div class="font-medium text-gray-900 dark:text-gray-100">{@title || "Unknown Section"}</div>
      <div class="text-xs text-gray-500 dark:text-gray-400">{@slug || "unknown-section"}</div>
    </div>
    """
  end

  def render_scope_column(assigns, row, _) do
    scope_label =
      case {row.scope_type, row.scope_container_id} do
        {:course, _} -> "Entire Course"
        {"course", _} -> "Entire Course"
        {:container, id} when is_integer(id) -> "Container ##{id}"
        {"container", id} when is_integer(id) -> "Container ##{id}"
        _ -> "Unknown Scope"
      end

    assigns = Map.put(assigns, :scope_label, scope_label)

    ~H"""
    <span class="text-sm">{@scope_label}</span>
    """
  end

  def render_user_column(assigns, %{user_id: user_id, user_name: name, user_email: email}, _) do
    assigns =
      Map.merge(assigns, %{
        user_id: user_id,
        name: name || "Unknown",
        email: email || "unknown"
      })

    ~H"""
    <div class="text-sm">
      <a
        :if={@user_id}
        href={Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersDetailView, @user_id)}
        class="font-medium text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300"
      >
        {@name}
      </a>
      <span :if={!@user_id} class="font-medium text-gray-900 dark:text-gray-100">{@name}</span>
      <div class="text-xs text-gray-500 dark:text-gray-400">{@email}</div>
    </div>
    """
  end

  def render_sentiment_column(assigns, %{sentiment: sentiment}, _) do
    sentiment_label =
      case sentiment do
        :thumbs_up -> "👍 Thumbs up"
        :thumbs_down -> "👎 Thumbs down"
        "thumbs_up" -> "👍 Thumbs up"
        "thumbs_down" -> "👎 Thumbs down"
        _ -> "Not provided"
      end

    assigns = Map.put(assigns, :sentiment_label, sentiment_label)

    ~H"""
    <span class="text-sm">{@sentiment_label}</span>
    """
  end

  def render_recommendation_id_column(assigns, %{recommendation_id: recommendation_id}, _) do
    assigns = Map.put(assigns, :recommendation_id, recommendation_id)

    ~H"""
    <span class="text-sm font-mono">{@recommendation_id}</span>
    """
  end

  def render_feedback_text_column(assigns, %{feedback_text: feedback_text}, _) do
    assigns = Map.put(assigns, :feedback_text, feedback_text || "")

    ~H"""
    <div class="text-sm max-w-[420px] break-words">{@feedback_text}</div>
    """
  end
end
