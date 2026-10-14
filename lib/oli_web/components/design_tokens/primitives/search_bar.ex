defmodule OliWeb.Components.DesignTokens.Primitives.SearchBar do
  @moduledoc """
  Shared, token-governed search-field primitive for HEEx and LiveView surfaces.

  The primitive owns the visual and accessibility contract for a search field while
  callers continue to own form boundaries, event handling, debounce behavior, and
  layout width. Its default width matches the 224px Torus design-system specimen;
  pass `class` to adapt it to wider or responsive layouts.

  The search icon is decorative. Callers must provide a contextual `aria_label`
  describing what the field searches. When `on_clear` is provided, a clear button
  appears only while `value` is non-empty and is announced as "Clear search."

  Use `interactive={false}` only for presentational artwork. That mode renders no
  form control and is hidden from the accessibility tree.
  """

  use Phoenix.Component

  alias OliWeb.Icons

  @type catalog_example :: %{
          label: String.t(),
          assigns: map()
        }

  @type catalog_section :: %{
          title: String.t(),
          examples: [catalog_example()]
        }

  @type catalog_entry :: %{
          name: String.t(),
          description: String.t(),
          figma_url: String.t(),
          sections: [catalog_section()]
        }

  @doc """
  Metadata consumed by `/dev/design_tokens`.
  """
  @spec catalog() :: catalog_entry()
  def catalog do
    %{
      name: "Search Bar",
      description: "Shared search-field primitive for HEEx / LiveView surfaces.",
      figma_url:
        "https://www.figma.com/design/4pTqLuqHbALAbZ31wvIHIX/NG-23---Torus-Design-System?node-id=4455-38704",
      sections: [
        %{
          title: "Search-Bar/States",
          examples: [
            %{
              label: "Default",
              assigns: %{
                id: "search-bar-default",
                aria_label: "Search example",
                state: :default
              }
            },
            %{
              label: "Hover",
              assigns: %{
                id: "search-bar-hover",
                aria_label: "Search example",
                state: :hover
              }
            },
            %{
              label: "Focused",
              assigns: %{
                id: "search-bar-focused",
                aria_label: "Search example",
                value: "Search term",
                state: :focused
              }
            },
            %{
              label: "With clear control",
              assigns: %{
                id: "search-bar-clearable",
                aria_label: "Search example",
                value: "Search term",
                on_clear: "clear_search"
              }
            }
          ]
        }
      ]
    }
  end

  @doc """
  Renders a representative Search Bar example for the design-tokens catalog.
  """
  def preview(assigns) do
    assigns =
      assigns
      |> Map.new()
      |> Map.put_new(:id, "search-bar-preview")
      |> Map.put_new(:aria_label, "Search example")
      |> Map.put_new(:value, "")
      |> Map.put_new(:placeholder, "Search")
      |> Map.put_new(:state, :default)
      |> Map.put_new(:on_clear, nil)

    ~H"""
    <.search_bar
      id={@id}
      aria_label={@aria_label}
      value={@value}
      placeholder={@placeholder}
      state={@state}
      on_clear={@on_clear}
    />
    """
  end

  attr :id, :string, required: true
  attr :name, :string, default: nil
  attr :value, :string, default: ""
  attr :placeholder, :string, default: ""
  attr :aria_label, :string, required: true
  attr :class, :any, default: nil
  attr :input_class, :any, default: nil
  attr :type, :string, values: ["search", "text"], default: "search"
  attr :state, :atom, values: [:default, :hover, :focused], default: :default
  attr :interactive, :boolean, default: true
  attr :on_clear, :any, default: nil
  attr :clear_target, :any, default: nil
  attr :clear_value_id, :string, default: nil
  attr :rest, :global

  @doc """
  Renders the shared Search Bar.

  `state` exists so the design-tokens catalog can display each canonical visual
  state side by side. Normal product usage should keep the default; CSS hover and
  focus-within variants provide the live interaction states.

  All global attributes are forwarded to the input, allowing callers to retain
  LiveView bindings such as `phx-debounce`, `phx-hook`, and `phx-target`.
  """
  def search_bar(assigns) do
    assigns = assign(assigns, :filled?, filled?(assigns.value))

    ~H"""
    <div
      class={[
        "group flex h-9 w-56 items-center gap-3 rounded-[6px] border border-Specially-Tokens-Border-border-input bg-Specially-Tokens-Fill-fill-input p-2 font-open-sans transition-[background-color,border-color,box-shadow] hover:border-Specially-Tokens-Border-border-input-focused hover:bg-Specially-Tokens-Fill-fill-input-focused hover:shadow-[0px_2px_6px_0px_rgba(0,52,99,0.15)] focus-within:border-Specially-Tokens-Border-border-input-focused focus-within:bg-Specially-Tokens-Fill-fill-input focus-within:shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] hover:focus-within:bg-Specially-Tokens-Fill-fill-input hover:focus-within:shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)]",
        state_classes(@state),
        @class
      ]}
      data-search-bar-state={@state}
      aria-hidden={if @interactive, do: nil, else: "true"}
    >
      <span class="flex h-5 w-5 shrink-0 items-center justify-center" aria-hidden="true">
        <Icons.search class="h-5 w-5 text-Icon-icon-default" />
      </span>

      <input
        :if={@interactive}
        id={@id}
        name={@name}
        type={@type}
        value={@value}
        placeholder={@placeholder}
        aria-label={@aria_label}
        class={[
          "h-5 min-w-0 flex-1 appearance-none border-0 bg-transparent p-0 font-open-sans text-sm font-normal leading-4 text-Text-text-high outline-none placeholder:text-Text-text-low-alpha focus:border-0 focus:outline-none focus:ring-0 focus:shadow-none [&::-webkit-search-cancel-button]:appearance-none [&::-webkit-search-decoration]:appearance-none",
          @input_class
        ]}
        {@rest}
      />

      <span
        :if={not @interactive}
        class={[
          "h-5 min-w-0 flex-1 truncate font-open-sans text-sm font-normal leading-4",
          if(@filled?, do: "text-Text-text-high", else: "text-Text-text-low-alpha")
        ]}
      >
        {if @filled?, do: @value, else: @placeholder}
      </span>

      <button
        :if={@interactive and @filled? and not is_nil(@on_clear)}
        id={@id <> "-clear"}
        type="button"
        aria-label="Clear search."
        phx-click={@on_clear}
        phx-target={@clear_target}
        phx-value-id={@clear_value_id}
        class="inline-flex h-5 w-5 shrink-0 items-center justify-center rounded-sm text-Icon-icon-default transition-colors hover:text-Icon-icon-hover focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
      >
        <Icons.close_sm class="h-4 w-4 stroke-current" />
      </button>
    </div>
    """
  end

  defp filled?(value), do: value not in [nil, ""]

  defp state_classes(:default), do: nil

  defp state_classes(:hover) do
    "border-Specially-Tokens-Border-border-input-focused bg-Specially-Tokens-Fill-fill-input-focused shadow-[0px_2px_6px_0px_rgba(0,52,99,0.15)]"
  end

  defp state_classes(:focused) do
    "border-Specially-Tokens-Border-border-input-focused bg-Specially-Tokens-Fill-fill-input shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)]"
  end
end
