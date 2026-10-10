defmodule OliWeb.ManualGrading.Tabs do
  use OliWeb, :html

  @tabs [review: "Student Submission", preview: "Activity Details"]

  attr :active, :atom, required: true
  attr :changed, :any, required: true

  attr :id, :string,
    default: nil,
    doc: "When set, arrow keys move between the tabs (ScoringTabs hook)."

  def render(assigns) do
    assigns = assign(assigns, :tabs, @tabs)

    ~H"""
    <div
      id={@id}
      role="tablist"
      aria-label="Submission views"
      phx-hook={@id && "ScoringTabs"}
      class="flex gap-6 border-b border-Border-border-subtle"
    >
      <button
        :for={{key, label} <- @tabs}
        type="button"
        role="tab"
        id={tab_id(@id, key)}
        aria-selected={to_string(@active == key)}
        aria-controls={panel_id(@id, key)}
        tabindex={if @active == key, do: "0", else: "-1"}
        phx-click={@changed}
        phx-value-tab={key}
        class={[
          "-mb-px border-b-2 px-1 py-2 text-sm font-semibold",
          if(@active == key,
            do: "border-Border-border-active text-Text-text-button",
            else: "border-transparent text-Text-text-low hover:text-Text-text-high"
          )
        ]}
      >
        {label}
      </button>
    </div>
    """
  end

  attr :id, :string, default: nil
  attr :active, :atom, required: true
  attr :key, :atom, required: true
  attr :class, :string, default: ""
  slot :inner_block, required: true

  @doc "The panel of one tab; rendered only while that tab is active."
  def panel(assigns) do
    ~H"""
    <div
      :if={@active == @key}
      role="tabpanel"
      id={panel_id(@id, @key)}
      aria-labelledby={tab_id(@id, @key)}
      tabindex="0"
      class={@class}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp tab_id(nil, key), do: "tab-#{key}"
  defp tab_id(id, key), do: "#{id}-tab-#{key}"
  defp panel_id(nil, key), do: "tabpanel-#{key}"
  defp panel_id(id, key), do: "#{id}-tabpanel-#{key}"
end
