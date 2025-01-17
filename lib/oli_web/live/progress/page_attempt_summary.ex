defmodule OliWeb.Progress.PageAttemptSummary do
  use OliWeb, :live_component
  alias Oli.Repo
  alias OliWeb.Common.Utils
  alias OliWeb.Delivery.Student.Utils, as: StudentUtils

  attr(:attempt, :map, required: true)
  attr(:section, :map, required: true)
  attr(:ctx, :map, required: true)
  attr(:revision, :map, required: true)
  attr(:request_path, :string, default: "")

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
    <div class="list-group-item list-group-action flex-column align-items-start mb-8">
      <.link
        href={
          StudentUtils.review_live_path(@section.slug, @revision.slug, @attempt.attempt_guid,
            request_path: @request_path
          )
        }
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
    activity_attempts =
      Repo.preload(assigns.attempt, activity_attempts: [:part_attempts]).activity_attempts

    feedback_texts = Utils.extract_feedback_text(activity_attempts)

    ~H"""
    <div class="list-group-item list-group-action flex-column align-items-start mb-8">
      <.link
        href={
          StudentUtils.review_live_path(@section.slug, @revision.slug, @attempt.attempt_guid,
            request_path: @request_path
          )
        }
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

      <div :if={feedback_texts != []} class="mt-8">
        <div class="text-black text-sm font-normal mb-2">Instructor Feedback:</div>
        <div class="flex flex-col gap-y-2">
          <%= for feedback <- feedback_texts do %>
            <textarea class="w-full bg-neutral-100 rounded-md border border-neutral-300" readonly>
            <%= feedback %>
          </textarea>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def do_render(%{attempt: %{lifecycle_state: :submitted}} = assigns) do
    ~H"""
    <div class="list-group-item list-group-action flex-column align-items-start mb-8">
      <.link
        href={
          StudentUtils.review_live_path(@section.slug, @revision.slug, @attempt.attempt_guid,
            request_path: @request_path
          )
        }
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
