defmodule OliWeb.Progress.PageAttemptSummary do
  use OliWeb, :live_component
  alias OliWeb.Common.Utils
  alias OliWeb.Delivery.Student.Utils, as: StudentUtils

  attr(:attempt, :map, required: true)
  attr(:section, :map, required: true)
  attr(:ctx, :map, required: true)
  attr(:revision, :map, required: true)

  @spec render(
          atom
          | %{
              :attempt => atom | %{:date_evaluated => any, optional(any) => any},
              optional(any) => any
            }
        ) :: Phoenix.LiveView.Rendered.t()
  def render(assigns), do: do_render(assigns)

  def do_render(
        %{revision: %{graded: _graded}, attempt: %{attempt_guid: _guid, lifecycle_state: :active}} =
          assigns
      ) do
    ~H"""
    <div class="list-group-item list-group-action flex-column align-items-start">
      <.link
        href={StudentUtils.review_live_path(@section.slug, @revision.slug, @attempt.attempt_guid)}
        class="block"
      >
        <div class="d-flex w-100 justify-content-between">
          <h5 class="mb-1">Attempt <%= @attempt.attempt_number %></h5>
          <span>Not Submitted Yet</span>
        </div>
        <p class="mb-1">Started: <%= Utils.render_date(@attempt, :inserted_at, @ctx) %></p>
        <small class="text-muted">
          Time elapsed: <%= duration(@attempt.inserted_at, DateTime.utc_now()) %>.
        </small>
      </.link>
      <%= if @revision.graded do %>
        <button
          class="btn btn-danger btn-sm"
          phx-click="submit_attempt"
          phx-value-guid={@attempt.attempt_guid}
        >
          Submit Attempt on Behalf of Student
        </button>
      <% end %>
    </div>
    """
  end

  def do_render(%{attempt: %{lifecycle_state: :evaluated}} = assigns) do
    ~H"""
    <div class="list-group-item list-group-action flex-column align-items-start">
      <.link
        href={StudentUtils.review_live_path(@section.slug, @revision.slug, @attempt.attempt_guid)}
        class="block"
      >
        <div class="d-flex w-100 justify-content-between">
          <h5 class="mb-1">Attempt <%= @attempt.attempt_number %></h5>
          <span><%= Utils.format_score(@attempt.score) %> / <%= @attempt.out_of || "-" %></span>
        </div>
        <div class="d-flex flex-row">
          <%= if @attempt.was_late do %>
            <.badge variant={:danger}>LATE</.badge>
          <% end %>
          <p class="mb-1 text-muted">
            Submitted: <%= Utils.render_date(@attempt, :date_evaluated, @ctx) %> (<%= Utils.render_relative_date(
              @attempt,
              :date_evaluated,
              @ctx
            ) %>)
          </p>
        </div>

        <small class="text-muted">
          Time elapsed: <%= duration(@attempt.inserted_at, @attempt.date_evaluated) %>.
        </small>
      </.link>
    </div>
    """
  end

  def do_render(%{attempt: %{lifecycle_state: :submitted}} = assigns) do
    ~H"""
    <div class="list-group-item list-group-action flex-column align-items-start">
      <.link
        href={StudentUtils.review_live_path(@section.slug, @revision.slug, @attempt.attempt_guid)}
        class="block"
      >
        <div class="d-flex w-100 justify-content-between">
          <h5 class="mb-1">Attempt <%= @attempt.attempt_number %></h5>
          <span>Submitted</span>
        </div>
        <p class="mb-1 text-muted">
          Submitted: <%= Utils.render_date(@attempt, :date_submitted, @ctx) %> (<%= Utils.render_relative_date(
            @attempt,
            :date_submitted,
            @ctx
          ) %>)
        </p>
        <small class="text-muted">
          Time elapsed: <%= duration(@attempt.inserted_at, @attempt.date_submitted) %>.
        </small>
      </.link>
    </div>
    """
  end
end
