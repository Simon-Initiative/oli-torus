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
      class="flex"
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
          "border-b-2 px-3 pb-3.5 pt-4 text-sm leading-4 text-Text-text-high",
          if(@active == key,
            do: "border-Fill-Buttons-fill-primary font-semibold",
            else: "border-transparent"
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
