defmodule OliWeb.ManualGrading.SelectedSubmission do
  use OliWeb, :html

  attr :submission, :map, default: nil
  attr :class, :string, default: ""

  def render(%{submission: nil} = assigns) do
    ~H"""
    <div class={[
      "rounded-xl bg-Surface-surface-primary px-5 py-6 shadow-[0px_2px_10px_0px_rgba(0,50,99,0.05)]",
      @class
    ]}>
      <div class="text-sm font-semibold text-Text-text-high">Student Submission</div>
      <div class="mt-1 text-sm text-Text-text-low">
        Select an input below to inspect the student submission for that part.
      </div>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class={[
      "rounded-xl bg-Surface-surface-primary px-5 py-5 shadow-[0px_2px_10px_0px_rgba(0,50,99,0.05)]",
      @class
    ]}>
      <div class="flex flex-col gap-3 border-b border-Border-border-subtle pb-4 lg:flex-row lg:items-start lg:justify-between">
        <div class="min-w-0">
          <div class="text-lg font-semibold text-Text-text-high">{@submission.title}</div>
          <div class="mt-1 text-sm text-Text-text-low">{@submission.subtitle}</div>
        </div>
        <div class="shrink-0 rounded-lg bg-Surface-surface-primary px-4 py-3">
          <div class="text-xs font-semibold uppercase tracking-wide text-Text-text-low">
            Recorded Score
          </div>
          <div class="mt-1 text-sm font-semibold text-Text-text-high">{@submission.score}</div>
        </div>
      </div>

      <div class="mt-5">
        {render_response_view(@submission.response_view)}
      </div>
    </div>
    """
  end

  defp render_response_view(%{kind: :choice_list} = view) do
    assigns = %{view: view}

    ~H"""
    <div class="grid grid-cols-1 gap-4 xl:grid-cols-[minmax(0,1.2fr)_minmax(18rem,0.8fr)]">
      <div class="rounded-xl bg-Surface-surface-secondary-muted px-4 py-4">
        <div class="text-sm font-semibold text-Text-text-high">{@view.prompt}</div>
        <div :if={@view.description} class="mt-1 text-sm text-Text-text-low">{@view.description}</div>
        <div class="mt-4 space-y-3">
          <%= for choice <- @view.choices do %>
            <div class={choice_row_classes(choice.selected)}>
              <div class={choice_indicator_classes(choice.selected)} />
              <div class="min-w-0 text-sm text-Text-text-high">{choice.label}</div>
            </div>
          <% end %>
        </div>
      </div>

      <div class="rounded-xl bg-Surface-surface-secondary-muted px-4 py-4">
        <div class="text-sm font-semibold text-Text-text-high">Selected Response</div>
        <div class="mt-3 min-h-[10rem] whitespace-pre-wrap break-words rounded-lg border border-Border-border-subtle bg-Surface-surface-secondary-muted px-4 py-4 text-sm leading-6 text-Text-text-high">
          {@view.selected_summary}
        </div>
      </div>
    </div>
    """
  end

  defp render_response_view(%{kind: :fill_blanks} = view) do
    assigns = %{view: view}

    ~H"""
    <div class="rounded-xl bg-Surface-surface-secondary-muted px-4 py-4">
      <div class="text-sm font-semibold text-Text-text-high">{@view.prompt}</div>
      <div :if={@view.description} class="mt-1 text-sm text-Text-text-low">{@view.description}</div>

      <div class="mt-4 grid grid-cols-1 gap-4 xl:grid-cols-2">
        <%= for blank <- @view.blanks do %>
          <div class="rounded-xl bg-Surface-surface-primary px-4 py-4">
            <div class="flex items-start justify-between gap-3">
              <div class="text-sm font-semibold text-Text-text-high">{blank.label}</div>
              <span :if={blank.meta} class={meta_badge_classes(blank.meta)}>{blank.meta}</span>
            </div>
            <div class="mt-3 whitespace-pre-wrap break-words text-sm leading-6 text-Text-text-high">
              {blank.value}
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_response_view(%{kind: :value} = view) do
    assigns = %{view: view}

    ~H"""
    <div class="grid grid-cols-1 gap-4 xl:grid-cols-[minmax(16rem,0.7fr)_minmax(0,1fr)]">
      <div class="rounded-xl bg-Surface-surface-secondary-muted px-4 py-4">
        <div class="text-sm font-semibold text-Text-text-high">{@view.prompt}</div>
        <div :if={@view.description} class="mt-1 text-sm text-Text-text-low">{@view.description}</div>
        <div class="mt-4 rounded-lg border border-Border-border-subtle bg-Surface-surface-secondary-muted px-4 py-6 text-center">
          <div class="text-xs font-semibold uppercase tracking-wide text-Text-text-low">
            Submission
          </div>
          <div class="mt-2 text-2xl font-semibold text-Text-text-high">{@view.value}</div>
        </div>
      </div>

      <div class="rounded-xl bg-Surface-surface-secondary-muted px-4 py-4">
        <div class="text-sm font-semibold text-Text-text-high">Details</div>
        <div class="mt-4 grid grid-cols-1 gap-3 lg:grid-cols-2">
          <%= for detail <- @view.details do %>
            <div class="rounded-lg bg-Surface-surface-primary px-4 py-3">
              <div class="text-xs font-semibold uppercase tracking-wide text-Text-text-low">
                {detail.label}
              </div>
              <div class="mt-2 whitespace-pre-wrap break-words text-sm leading-6 text-Text-text-high">
                {detail.value}
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_response_view(%{kind: :prose} = view) do
    assigns = %{view: view}

    ~H"""
    <div class="grid grid-cols-1 gap-4 xl:grid-cols-[minmax(0,1fr)_18rem]">
      <div class="rounded-xl bg-Surface-surface-secondary-muted px-4 py-4">
        <div class="text-sm font-semibold text-Text-text-high">{@view.prompt}</div>
        <div :if={@view.description} class="mt-1 text-sm text-Text-text-low">{@view.description}</div>
        <div class="mt-4 rounded-lg bg-Surface-surface-primary px-5 py-5">
          <div class="text-xs font-semibold uppercase tracking-wide text-Text-text-low">
            Submission
          </div>
          <div class="mt-4 whitespace-pre-wrap break-words text-left text-base leading-8 text-Text-text-high">
            {@view.value}
          </div>
        </div>
      </div>

      <div :if={@view.details != []} class="rounded-xl bg-Surface-surface-secondary-muted px-4 py-4">
        <div class="text-sm font-semibold text-Text-text-high">Details</div>
        <div class="mt-4 space-y-3">
          <%= for detail <- @view.details do %>
            <div class="rounded-lg bg-Surface-surface-primary px-4 py-3">
              <div class="text-xs font-semibold uppercase tracking-wide text-Text-text-low">
                {detail.label}
              </div>
              <div class="mt-2 whitespace-pre-wrap break-words text-sm leading-6 text-Text-text-high">
                {detail.value}
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_response_view(%{kind: :details} = view) do
    assigns = %{view: view}

    ~H"""
    <div class="rounded-xl bg-Surface-surface-secondary-muted px-4 py-4">
      <div class="text-sm font-semibold text-Text-text-high">{@view.prompt}</div>
      <div :if={@view.description} class="mt-1 text-sm text-Text-text-low">{@view.description}</div>
      <div class="mt-4 grid grid-cols-1 gap-4 xl:grid-cols-2">
        <%= for detail <- @view.details do %>
          <div class="rounded-xl bg-Surface-surface-primary px-4 py-4">
            <div class="text-sm font-semibold text-Text-text-high">{detail.label}</div>
            <div class="mt-3 whitespace-pre-wrap break-words text-sm leading-6 text-Text-text-high">
              {detail.value}
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_response_view(_view) do
    assigns = %{}

    ~H"""
    <div class="rounded-xl bg-Surface-surface-secondary-muted px-4 py-4 text-sm text-Text-text-low">
      No submission details are available for this input.
    </div>
    """
  end

  defp choice_row_classes(true),
    do:
      "flex items-start gap-3 rounded-lg border border-Border-border-bold bg-Surface-surface-secondary-hover px-4 py-3"

  defp choice_row_classes(false),
    do:
      "flex items-start gap-3 rounded-lg border border-Border-border-subtle bg-Surface-surface-secondary-muted px-4 py-3"

  defp choice_indicator_classes(true),
    do: "mt-1 h-3 w-3 shrink-0 rounded-full bg-Fill-Accent-fill-accent-blue-bold"

  defp choice_indicator_classes(false),
    do:
      "mt-1 h-3 w-3 shrink-0 rounded-full border border-Border-border-default bg-Surface-surface-primary"

  defp meta_badge_classes("Correct"),
    do:
      "inline-flex items-center rounded-full bg-Fill-Accent-fill-accent-teal px-2.5 py-1 text-xs font-semibold text-Text-text-accent-teal"

  defp meta_badge_classes("Incorrect"),
    do:
      "inline-flex items-center rounded-full bg-Fill-Accent-fill-accent-orange px-2.5 py-1 text-xs font-semibold text-Text-text-accent-orange"

  defp meta_badge_classes(_),
    do:
      "inline-flex items-center rounded-full bg-Surface-surface-secondary-hover px-2.5 py-1 text-xs font-semibold text-Text-text-low"
end
