defmodule OliWeb.Components.FilterPanel do
  use OliWeb, :html

  alias Phoenix.LiveView.JS
  alias OliWeb.Icons

  attr :id, :string, required: true
  attr :open, :boolean, default: false
  attr :filters, :map, required: true
  attr :fields, :list, default: [:date, :tags, :visibility, :published, :status, :institution]
  attr :active_count, :integer, default: 0

  attr :toggle_event, :string, default: "toggle_filters"
  attr :close_event, :string, default: "close_filters"
  attr :cancel_event, :string, default: "cancel_filters"
  attr :apply_event, :string, default: "apply_filters"
  attr :clear_event, :string, required: true
  attr :tag_add_event, :string, default: "filter_add_tag"
  attr :tag_remove_event, :string, default: "filter_remove_tag"
  attr :tag_search_event, :string, default: "filter_tag_search"
  attr :target, :any, default: nil

  attr :tag_search, :string, default: ""
  attr :tag_suggestions, :list, default: []
  attr :date_field_options, :list, default: []
  attr :visibility_options, :list, default: []
  attr :status_options, :list, default: []
  attr :published_options, :list, default: []
  attr :institution_options, :list, default: []

  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:form_id, fn -> "#{assigns.id}-form" end)

    ~H"""
    <div id={@id} class="relative flex items-center gap-4">
      <button
        class="ml-2 text-center text-Text-text-high text-sm font-normal leading-none flex items-center gap-x-1 hover:text-Text-text-button"
        phx-click={@toggle_event}
        phx-target={@target}
        type="button"
      >
        <Icons.filter class="stroke-Text-text-high" />
        <span>Filter</span>
        <span
          :if={@active_count > 0}
          class="ml-1 inline-flex h-5 min-w-[1.25rem] items-center justify-center rounded-full bg-Text-text-button px-1 text-xs font-semibold text-Text-text-white"
        >
          {@active_count}
        </span>
      </button>

      <button
        class="ml-2 mr-4 text-center text-Text-text-high text-sm font-normal leading-none flex items-center gap-x-1 hover:text-Text-text-button"
        phx-click={@clear_event}
        phx-target={@target}
        type="button"
      >
        <Icons.trash /> Clear All Filters
      </button>

      <div
        id={"#{@id}-panel"}
        class={[
          "absolute left-0 top-10 z-50 w-[430px] rounded-lg border border-Border-border-default bg-Surface-surface-primary shadow-[0px_12px_24px_0px_rgba(53,55,64,0.12)]",
          if(@open, do: "", else: "hidden")
        ]}
        phx-click-away={push_with_target(@close_event, @target)}
      >
        <.form
          id={@form_id}
          for={%{}}
          as={:filters}
          phx-submit={@apply_event}
          phx-target={@target}
          class="flex flex-col gap-4 p-5"
        >
          <%= if :date in @fields do %>
            <div class="flex flex-col gap-2">
              <div class="flex flex-col gap-1">
                <span class="text-sm font-semibold text-Text-text-high">Date</span>
                <span class="text-xs text-Text-text-low-alpha">
                  If both dates are specified, they will be interpreted as a range.
                </span>
              </div>
              <div class="flex flex-col gap-2">
                <select
                  name="filters[date_field]"
                  class="h-9 rounded border border-Border-border-default px-3 text-sm text-Text-text-high dark:bg-transparent"
                  value={encode_atom(@filters[:date_field])}
                >
                  <option
                    :for={{value, label} <- date_field_option_values(@date_field_options)}
                    value={value}
                    selected={value == encode_atom(@filters[:date_field])}
                  >
                    {label}
                  </option>
                </select>
                <div class="flex items-center gap-2">
                  <div class="flex flex-1 flex-col gap-1">
                    <label class="text-xs font-medium text-Text-text-low-alpha">
                      is after
                    </label>
                    <input
                      type="date"
                      name="filters[date_from]"
                      value={format_date(@filters[:date_from])}
                      class="h-9 rounded border border-Border-border-default px-3 text-sm text-Text-text-high dark:bg-transparent"
                    />
                  </div>
                  <div class="mt-6 text-xs text-Text-text-low-alpha">and/or before</div>
                  <div class="flex flex-1 flex-col gap-1">
                    <label class="text-xs font-medium text-Text-text-low-alpha invisible">
                      and/or before
                    </label>
                    <input
                      type="date"
                      name="filters[date_to]"
                      value={format_date(@filters[:date_to])}
                      class="h-9 rounded border border-Border-border-default px-3 text-sm text-Text-text-high dark:bg-transparent"
                    />
                  </div>
                </div>
              </div>
            </div>
          <% end %>

          <%= if :tags in @fields do %>
            <div class="flex flex-col gap-2">
              <span class="text-sm font-semibold text-Text-text-high">Tags</span>
              <div class="flex flex-wrap gap-2">
                <%= for tag <- @filters[:tags] || [] do %>
                  <span class="inline-flex items-center gap-2 rounded-full bg-Specially-Tokens-Fill-fill-dot-message-default px-3 py-1 text-xs font-medium text-Text-text-button">
                    {tag.name}
                    <button
                      type="button"
                      class="text-Text-text-button hover:text-Text-text-button-hover"
                      phx-click={@tag_remove_event}
                      phx-target={@target}
                      phx-value-id={tag.id}
                    >
                      ×
                    </button>
                  </span>
                <% end %>
              </div>

              <%= for tag <- @filters[:tags] || [] do %>
                <input type="hidden" name="filters[tag_ids][]" value={tag.id} />
              <% end %>

              <input
                type="text"
                id={"#{@id}-tag-search"}
                name="filters[tag_search_input]"
                value={@tag_search}
                placeholder="Enter tags"
                phx-keyup={@tag_search_event}
                phx-target={@target}
                phx-debounce="300"
                class="h-9 rounded border border-Border-border-default px-3 text-sm text-Text-text-high focus:border-Text-text-button focus:outline-none dark:bg-transparent"
              />

              <div
                :if={Enum.any?(@tag_suggestions)}
                class="flex flex-col gap-1 rounded border border-Border-border-default bg-Specially-Tokens-Fill-fill-nav-hover p-2"
              >
                <button
                  :for={suggestion <- @tag_suggestions}
                  type="button"
                  class="rounded px-2 py-1 text-left text-sm text-Text-text-high hover:bg-Specially-Tokens-Fill-fill-dot-message-default"
                  phx-click={@tag_add_event}
                  phx-target={@target}
                  phx-value-id={suggestion.id}
                  phx-value-name={suggestion.name}
                >
                  {suggestion.name}
                </button>
              </div>
            </div>
          <% end %>

          <%= if :visibility in @fields do %>
            <div class="flex flex-col gap-2">
              <label class="text-sm font-semibold text-Text-text-high">
                Visibility
              </label>
              <select
                name="filters[visibility]"
                class="h-9 rounded border border-Border-border-default px-3 text-sm text-Text-text-high dark:bg-transparent"
                value={encode_atom(@filters[:visibility])}
              >
                <option value="">Select option</option>
                <option
                  :for={{value, label} <- @visibility_options}
                  value={Atom.to_string(value)}
                  selected={value == @filters[:visibility]}
                >
                  {label}
                </option>
              </select>
            </div>
          <% end %>

          <%= if :published in @fields do %>
            <div class="flex flex-col gap-2">
              <label class="text-sm font-semibold text-Text-text-high">
                Published
              </label>
              <select
                name="filters[published]"
                class="h-9 rounded border border-Border-border-default px-3 text-sm text-Text-text-high dark:bg-transparent"
                value={encode_boolean(@filters[:published])}
              >
                <option value="">Select option</option>
                <option
                  :for={{value, label} <- @published_options}
                  value={encode_boolean(value)}
                  selected={value == @filters[:published]}
                >
                  {label}
                </option>
              </select>
            </div>
          <% end %>

          <%= if :status in @fields do %>
            <div class="flex flex-col gap-2">
              <label class="text-sm font-semibold text-Text-text-high">Status</label>
              <select
                name="filters[status]"
                class="h-9 rounded border border-Border-border-default px-3 text-sm text-Text-text-high dark:bg-transparent"
                value={encode_atom(@filters[:status])}
              >
                <option value="">Select option</option>
                <option
                  :for={{value, label} <- @status_options}
                  value={Atom.to_string(value)}
                  selected={value == @filters[:status]}
                >
                  {label}
                </option>
              </select>
            </div>
          <% end %>

          <%= if :institution in @fields do %>
            <div class="flex flex-col gap-2">
              <label class="text-sm font-semibold text-Text-text-high">
                Institution
              </label>
              <select
                name="filters[institution]"
                class="h-9 rounded border border-Border-border-default px-3 text-sm text-Text-text-high dark:bg-transparent"
                value={encode_integer(@filters[:institution_id])}
              >
                <option value="">Select option</option>
                <option
                  :for={institution <- @institution_options}
                  value={Integer.to_string(institution.id)}
                  selected={institution.id == @filters[:institution_id]}
                >
                  {institution.name}
                </option>
              </select>
            </div>
          <% end %>

          <div class="flex justify-end gap-3 pt-2">
            <button
              type="button"
              class="text-sm font-semibold text-Text-text-button hover:text-Text-text-button-hover"
              phx-click={@cancel_event}
              phx-target={@target}
            >
              Cancel
            </button>
            <button
              type="submit"
              class="rounded bg-Fill-Buttons-fill-primary px-4 py-2 text-sm font-semibold text-Text-text-white hover:bg-Fill-Buttons-fill-primary-hover"
            >
              Apply
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  defp date_field_option_values([]), do: [{"inserted_at", "Created Date"}]
  defp date_field_option_values(options), do: options

  defp format_date(nil), do: nil
  defp format_date(%Date{} = date), do: Date.to_iso8601(date)

  defp encode_atom(nil), do: ""
  defp encode_atom(atom) when is_atom(atom), do: Atom.to_string(atom)

  defp encode_boolean(nil), do: ""
  defp encode_boolean(value) when is_boolean(value), do: if(value, do: "true", else: "false")

  defp encode_integer(nil), do: ""
  defp encode_integer(int) when is_integer(int), do: Integer.to_string(int)

  defp push_with_target(event, nil), do: JS.push(event)
  defp push_with_target(event, target), do: JS.push(event, target: target)
end
