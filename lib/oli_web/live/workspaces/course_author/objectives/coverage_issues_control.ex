defmodule OliWeb.Workspaces.CourseAuthor.Objectives.CoverageIssuesControl do
  @moduledoc """
  Presentation component for the Coverage Issues filter toggle. The caller
  supplies the affected-objective count, active state, and click action; the
  component exposes the toggle state through `aria-pressed`.
  """
  use Phoenix.Component

  alias OliWeb.Icons

  attr :count, :integer, required: true
  attr :active, :boolean, default: false
  attr :click, :any, default: nil
  attr :id, :string, default: nil

  def coverage_issues_control(assigns) do
    ~H"""
    <button
      type="button"
      id={@id}
      phx-click={@click}
      aria-pressed={to_string(@active)}
      class={[
        "inline-flex h-[38px] shrink-0 items-center gap-2 rounded-md border border-Border-border-default px-3 text-sm font-semibold text-Text-text-high transition hover:bg-Surface-surface-secondary-hover focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary",
        if(@active, do: "bg-Fill-fill-danger", else: "bg-Background-bg-primary")
      ]}
    >
      <span aria-hidden="true">
        <Icons.warning_triangle class="h-[13px] w-[14px] stroke-Text-text-danger" />
      </span>
      <span class="whitespace-nowrap">Coverage Issues</span>
      <span class={[
        "inline-flex min-w-[19px] items-center justify-center rounded-full px-[6px] py-[2px] text-[11px] font-bold leading-[11px]",
        if(@active,
          do: "bg-[#CE2C31] text-white dark:bg-[#33181A] dark:text-[#EEEBF5]",
          else: "bg-Fill-fill-danger text-Table-text-danger"
        )
      ]}>
        {@count}
      </span>
    </button>
    """
  end
end
