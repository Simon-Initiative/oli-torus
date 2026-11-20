defmodule OliWeb.Components.DesignTokens.Primitives.RadioGroup do
  @moduledoc """
  Shared, token-governed radio group primitive for HEEx and LiveView surfaces.

  Renders a `<fieldset>` whose `<legend>` names the choice, and one native
  `<input type="radio">` per option, all sharing `name`, each with its own
  label. Keyboard navigation, focus and screen-reader announcements therefore
  come from the platform. The visible circle follows the design system's
  "Radio-Button" / "Radio-Item" components and the input's native checked
  state.

  Callers own the form boundary and the events: put the group inside a form
  with `phx-change` to receive the chosen `value` under `name`. Use
  `orientation={:horizontal}` for a short inline choice and `legend_class` to
  lay the legend out beside the options.
  """

  use Phoenix.Component

  @type option :: %{value: String.t() | atom(), label: String.t()}

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
      name: "Radio Group",
      description: "Shared radio-group primitive for HEEx / LiveView surfaces.",
      figma_url:
        "https://www.figma.com/design/4pTqLuqHbALAbZ31wvIHIX/NG-23---Torus-Design-System?node-id=4455-38780",
      sections: [
        %{
          title: "Radio-Item/Orientation",
          examples: [
            %{
              label: "Vertical",
              assigns: %{
                id: "radio-group-vertical",
                name: "radio-group-vertical",
                legend: "Availability",
                options: example_options(),
                value: "private",
                orientation: :vertical
              }
            },
            %{
              label: "Horizontal",
              assigns: %{
                id: "radio-group-horizontal",
                name: "radio-group-horizontal",
                legend: "Availability",
                options: example_options(),
                value: "public",
                orientation: :horizontal
              }
            }
          ]
        }
      ]
    }
  end

  @doc """
  Renders a representative Radio Group example for the design-tokens catalog.
  """
  def preview(assigns) do
    assigns =
      assigns
      |> Map.new()
      |> Map.put_new(:id, "radio-group-preview")
      |> Map.put_new(:name, "radio-group-preview")
      |> Map.put_new(:legend, "Availability")
      |> Map.put_new(:options, example_options())
      |> Map.put_new(:value, nil)
      |> Map.put_new(:orientation, :vertical)

    ~H"""
    <.radio_group
      id={@id}
      name={@name}
      legend={@legend}
      options={@options}
      value={@value}
      orientation={@orientation}
    />
    """
  end

  defp example_options do
    [%{value: "public", label: "Public"}, %{value: "private", label: "Private"}]
  end

  attr :id, :string, required: true, doc: "the fieldset id; each input's id is derived from it"
  attr :name, :string, required: true, doc: "the name every radio shares"
  attr :legend, :string, required: true, doc: "names the choice for assistive technology"
  attr :options, :list, required: true, doc: "a list of `%{value: value, label: label}`"
  attr :value, :any, default: nil, doc: "the selected option's value; nil selects none"
  attr :orientation, :atom, values: [:vertical, :horizontal], default: :vertical
  attr :class, :any, default: nil
  attr :legend_class, :any, default: nil
  attr :rest, :global

  @doc """
  Renders the shared Radio Group.

  An option is checked when its `value` equals `value`, compared as strings, so
  atoms and strings can be mixed. Global attributes are forwarded to the
  fieldset.
  """
  def radio_group(assigns) do
    ~H"""
    <fieldset id={@id} class={["m-0 min-w-0 border-0 p-0", @class]} {@rest}>
      <legend class={[
        "p-0 font-sans text-base font-normal leading-6 text-Text-text-high",
        @legend_class
      ]}>
        {@legend}
      </legend>
      <div class={orientation_classes(@orientation)}>
        <label
          :for={option <- @options}
          for={input_id(@id, option.value)}
          class="group flex cursor-pointer items-start gap-3"
        >
          <input
            type="radio"
            id={input_id(@id, option.value)}
            name={@name}
            value={option.value}
            checked={selected?(option.value, @value)}
            class="peer sr-only"
          />
          <span
            aria-hidden="true"
            class="mt-1 h-4 w-4 shrink-0 rounded-full border border-Border-border-active bg-transparent transition-colors group-hover:bg-Fill-fill-hover peer-checked:border-Border-border-bold peer-checked:bg-Fill-Buttons-fill-primary peer-focus-visible:outline peer-focus-visible:outline-2 peer-focus-visible:outline-offset-2 peer-focus-visible:outline-Fill-Buttons-fill-primary"
          />
          <span class="font-sans text-base font-normal leading-6 text-Text-text-high">
            {option.label}
          </span>
        </label>
      </div>
    </fieldset>
    """
  end

  defp orientation_classes(:vertical), do: "flex flex-col gap-2"
  defp orientation_classes(:horizontal), do: "flex flex-wrap items-center gap-x-6 gap-y-2"

  defp input_id(id, value), do: "#{id}-#{value}"

  defp selected?(_option_value, nil), do: false
  defp selected?(option_value, value), do: to_string(option_value) == to_string(value)
end
