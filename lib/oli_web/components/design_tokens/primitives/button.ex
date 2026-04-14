defmodule OliWeb.Components.DesignTokens.Primitives.Button do
  @moduledoc """
  Shared button primitive for token-governed HEEx surfaces.

  This primitive is aligned to the Torus design-system button definitions in Figma
  and is intended to cover the canonical button families used across the product:

  - medium primary / secondary / text
  - small primary / secondary / danger / text
  - small buttons with left/right icons
  - pill / dropdown buttons
  - close buttons

  Domain-specific components should compose this primitive instead of re-owning
  baseline button visuals and states locally.

  Text sizing semantics:

  - default behavior keeps a free, content-driven width and shows the full label
  - `text_behavior={:wrap}` uses the component's default constrained width and grows vertically
  - `text_behavior={:truncate}` uses that same default constrained width and truncates with ellipsis
  - pass `width` only when you want to override that constrained width

  Canonical HEEx usage:

  ```heex
  <Button.button variant={:primary} size={:md}>
    Save
  </Button.button>
  ```

  ```heex
  <Button.button variant={:primary} size={:sm}>
    <:icon_left>
      <Icons.email class="h-4 w-4 stroke-current" />
    </:icon_left>
    Send Emails
  </Button.button>
  ```

  ```heex
  <Button.button variant={:pill} phx-click="toggle_filters" phx-target={@myself} active={@open}>
    Filters
    <:icon_right>
      <Icons.chevron_down class="h-4 w-4 stroke-current" />
    </:icon_right>
  </Button.button>
  ```

  ```heex
  <Button.button variant={:primary} text_behavior={:truncate}>
    Save changes for all selected students
  </Button.button>
  ```
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
          figma_url: String.t() | nil,
          sections: [catalog_section()]
        }

  @doc """
  Metadata consumed by `/dev/design_tokens`.
  """
  @spec catalog() :: catalog_entry()
  def catalog do
    %{
      name: "Button",
      description: "Shared button primitive for HEEx / LiveView surfaces.",
      figma_url:
        "https://www.figma.com/design/4pTqLuqHbALAbZ31wvIHIX/NG-23---Torus-Design-System?node-id=971-16994&t=dR4PsJGsZkE4bfrb-4",
      sections: [
        %{
          title: "Button/Medium",
          examples: [
            %{label: "Primary", assigns: %{variant: :primary, size: :md}},
            %{label: "Secondary", assigns: %{variant: :secondary, size: :md}},
            %{label: "Text", assigns: %{variant: :text, size: :md}},
            %{
              label: "text_behavior={:default}",
              assigns: %{
                variant: :primary,
                size: :md,
                label: "Save changes for all selected students"
              }
            },
            %{
              label: "text_behavior={:wrap}",
              assigns: %{
                variant: :primary,
                size: :md,
                text_behavior: :wrap,
                label: "Save changes for all selected students"
              }
            },
            %{
              label: "text_behavior={:truncate}",
              assigns: %{
                variant: :primary,
                size: :md,
                text_behavior: :truncate,
                label: "Save changes for all selected students"
              }
            }
          ]
        },
        %{
          title: "Button/Small",
          examples: [
            %{label: "Primary", assigns: %{variant: :primary, size: :sm}},
            %{label: "Secondary", assigns: %{variant: :secondary, size: :sm}},
            %{label: "Danger", assigns: %{variant: :danger, size: :sm}},
            %{label: "Text", assigns: %{variant: :text, size: :sm}},
            %{
              label: "text_behavior={:default}",
              assigns: %{
                variant: :primary,
                size: :sm,
                label: "Save changes for all selected students"
              }
            },
            %{
              label: "text_behavior={:wrap}",
              assigns: %{
                variant: :primary,
                size: :sm,
                text_behavior: :wrap,
                label: "Save changes for all selected students"
              }
            },
            %{
              label: "text_behavior={:truncate}",
              assigns: %{
                variant: :primary,
                size: :sm,
                text_behavior: :truncate,
                label: "Save changes for all selected students"
              }
            }
          ]
        },
        %{
          title: "Button/Small-w-Icon",
          examples: [
            %{
              label: "Icon Right",
              assigns: %{variant: :primary, size: :sm, icon_position: :right}
            },
            %{
              label: "Icon Left",
              assigns: %{variant: :primary, size: :sm, icon_position: :left}
            },
            %{
              label: "Icon Right Muted",
              assigns: %{variant: :primary, size: :sm, icon_position: :right, muted: true}
            },
            %{
              label: "Icon Left Muted",
              assigns: %{variant: :primary, size: :sm, icon_position: :left, muted: true}
            },
            %{
              label: "text_behavior={:default}",
              assigns: %{
                variant: :primary,
                size: :sm,
                icon_position: :right,
                label: "Save changes for all selected students"
              }
            },
            %{
              label: "text_behavior={:wrap}",
              assigns: %{
                variant: :primary,
                size: :sm,
                icon_position: :right,
                text_behavior: :wrap,
                label: "Save changes for all selected students"
              }
            },
            %{
              label: "text_behavior={:truncate}",
              assigns: %{
                variant: :primary,
                size: :sm,
                icon_position: :right,
                text_behavior: :truncate,
                label: "Save changes for all selected students"
              }
            }
          ]
        },
        %{
          title: "Button/Pill",
          examples: [
            %{label: "Dropdown", assigns: %{variant: :pill, active: false}},
            %{label: "Dropdown Active", assigns: %{variant: :pill, active: true}},
            %{label: "Dropdown Muted", assigns: %{variant: :pill, active: false, muted: true}},
            %{
              label: "Dropdown Muted Active",
              assigns: %{variant: :pill, active: true, muted: true}
            },
            %{
              label: "text_behavior={:default}",
              assigns: %{
                variant: :pill,
                active: false,
                label: "Save changes for all selected students"
              }
            },
            %{
              label: "text_behavior={:wrap}",
              assigns: %{
                variant: :pill,
                active: false,
                text_behavior: :wrap,
                label: "Save changes for all selected students"
              }
            },
            %{
              label: "text_behavior={:truncate}",
              assigns: %{
                variant: :pill,
                active: false,
                text_behavior: :truncate,
                label: "Save changes for all selected students"
              }
            }
          ]
        },
        %{
          title: "Button/Close",
          examples: [%{label: "Close", assigns: %{variant: :close}}]
        }
      ]
    }
  end

  @doc """
  Render a representative preview for the dev design-tokens catalog.
  """
  def preview(assigns) do
    assigns =
      assigns
      |> normalize_preview_assigns()
      |> Map.put_new(:label, preview_label())

    ~H"""
    <%= if @variant == :close do %>
      <.button variant={:close} aria-label="Close example" disabled={@disabled} />
    <% else %>
      <.button
        variant={@variant}
        size={@size}
        width={@width}
        text_behavior={@text_behavior}
        muted={@muted}
        active={@active}
        disabled={@disabled}
        aria-label={@label}
      >
        <:icon_left :if={@icon_position == :left}>
          <Icons.chevron_right class={icon_classes()} />
        </:icon_left>
        {@label}
        <:icon_right :if={@icon_position == :right and @variant != :pill}>
          <Icons.chevron_right class={icon_classes()} />
        </:icon_right>
        <:icon_right :if={@variant == :pill}>
          <%= if @active do %>
            <Icons.chevron_up class={icon_classes()} />
          <% else %>
            <Icons.chevron_down class={icon_classes()} />
          <% end %>
        </:icon_right>
      </.button>
    <% end %>
    """
  end

  attr :variant, :atom,
    default: :primary,
    values: [:primary, :secondary, :danger, :text, :pill, :close]

  attr :size, :atom, default: :sm, values: [:sm, :md]
  attr :width, :string, default: nil
  attr :text_behavior, :atom, default: :default, values: [:default, :wrap, :truncate]
  attr :muted, :boolean, default: false
  attr :active, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :href, :string, default: nil
  attr :navigate, :string, default: nil
  attr :patch, :string, default: nil
  attr :type, :string, default: "button"
  attr :class, :string, default: nil

  attr :rest, :global,
    include:
      ~w(form name value target rel method download aria-label aria-expanded title phx-click phx-target tabindex)

  slot :icon_left
  slot :inner_block
  slot :icon_right

  @doc """
  Render a shared button primitive.
  """
  def button(assigns) do
    assigns = normalize_button_assigns(assigns)

    ~H"""
    <% truncate_fallback_label_text =
      if @text_behavior == :truncate and
           (is_nil(@rest["title"]) or is_nil(@rest["aria-label"])) do
        slot_plain_text(render_slot(@inner_block))
      else
        nil
      end %>
    <%= case {@variant, @link_kind} do %>
      <% {:close, _} -> %>
        <button
          type={@type}
          class={[close_classes(@disabled), @class]}
          aria-label={close_aria_label(@rest["aria-label"])}
          title={close_title(@rest["title"], @rest["aria-label"])}
          disabled={@disabled}
          {@rest}
        >
          <Icons.close_sm class={close_icon_classes()} />
        </button>
      <% {_, :button} -> %>
        <button
          type={@type}
          class={[
            base_classes(@variant),
            interaction_classes(@disabled),
            size_classes(@variant, @size, @text_behavior),
            width_classes(@width, @text_behavior),
            variant_classes(@variant, @muted, @disabled),
            @class
          ]}
          aria-label={
            aria_label_text(@text_behavior, @rest["aria-label"], truncate_fallback_label_text)
          }
          aria-expanded={@aria_expanded}
          title={title_text(@text_behavior, @rest["title"], truncate_fallback_label_text)}
          disabled={@disabled}
          {@rest}
        >
          <span :if={@icon_left != []} class="inline-flex shrink-0 items-center justify-center">
            {render_slot(@icon_left)}
          </span>
          <span :if={@inner_block != []} class="flex min-w-0 flex-1 items-center justify-center">
            <span class={text_behavior_classes(@text_behavior)}>{render_slot(@inner_block)}</span>
          </span>
          <span :if={@icon_right != []} class="inline-flex shrink-0 items-center justify-center">
            {render_slot(@icon_right)}
          </span>
        </button>
      <% {_, :href} -> %>
        <a
          href={@href}
          class={[
            base_classes(@variant),
            interaction_classes(@disabled),
            size_classes(@variant, @size, @text_behavior),
            width_classes(@width, @text_behavior),
            variant_classes(@variant, @muted, @disabled),
            @class
          ]}
          aria-label={
            aria_label_text(@text_behavior, @rest["aria-label"], truncate_fallback_label_text)
          }
          aria-disabled={to_string(@disabled)}
          title={title_text(@text_behavior, @rest["title"], truncate_fallback_label_text)}
          tabindex={if @disabled, do: "-1", else: @rest["tabindex"]}
          {@rest}
        >
          <span :if={@icon_left != []} class="inline-flex shrink-0 items-center justify-center">
            {render_slot(@icon_left)}
          </span>
          <span :if={@inner_block != []} class="flex min-w-0 flex-1 items-center justify-center">
            <span class={text_behavior_classes(@text_behavior)}>{render_slot(@inner_block)}</span>
          </span>
          <span :if={@icon_right != []} class="inline-flex shrink-0 items-center justify-center">
            {render_slot(@icon_right)}
          </span>
        </a>
      <% {_, :navigate} -> %>
        <.link
          navigate={@navigate}
          class={[
            base_classes(@variant),
            interaction_classes(@disabled),
            size_classes(@variant, @size, @text_behavior),
            width_classes(@width, @text_behavior),
            variant_classes(@variant, @muted, @disabled),
            @class
          ]}
          aria-label={
            aria_label_text(@text_behavior, @rest["aria-label"], truncate_fallback_label_text)
          }
          aria-disabled={to_string(@disabled)}
          title={title_text(@text_behavior, @rest["title"], truncate_fallback_label_text)}
          tabindex={if @disabled, do: "-1", else: @rest["tabindex"]}
          {@rest}
        >
          <span :if={@icon_left != []} class="inline-flex shrink-0 items-center justify-center">
            {render_slot(@icon_left)}
          </span>
          <span :if={@inner_block != []} class="flex min-w-0 flex-1 items-center justify-center">
            <span class={text_behavior_classes(@text_behavior)}>{render_slot(@inner_block)}</span>
          </span>
          <span :if={@icon_right != []} class="inline-flex shrink-0 items-center justify-center">
            {render_slot(@icon_right)}
          </span>
        </.link>
      <% {_, :patch} -> %>
        <.link
          patch={@patch}
          class={[
            base_classes(@variant),
            interaction_classes(@disabled),
            size_classes(@variant, @size, @text_behavior),
            width_classes(@width, @text_behavior),
            variant_classes(@variant, @muted, @disabled),
            @class
          ]}
          aria-label={
            aria_label_text(@text_behavior, @rest["aria-label"], truncate_fallback_label_text)
          }
          aria-disabled={to_string(@disabled)}
          title={title_text(@text_behavior, @rest["title"], truncate_fallback_label_text)}
          tabindex={if @disabled, do: "-1", else: @rest["tabindex"]}
          {@rest}
        >
          <span :if={@icon_left != []} class="inline-flex shrink-0 items-center justify-center">
            {render_slot(@icon_left)}
          </span>
          <span :if={@inner_block != []} class="flex min-w-0 flex-1 items-center justify-center">
            <span class={text_behavior_classes(@text_behavior)}>{render_slot(@inner_block)}</span>
          </span>
          <span :if={@icon_right != []} class="inline-flex shrink-0 items-center justify-center">
            {render_slot(@icon_right)}
          </span>
        </.link>
    <% end %>
    """
  end

  defp normalize_preview_assigns(assigns) when is_list(assigns),
    do: normalize_preview_assigns(Enum.into(assigns, %{}))

  defp normalize_preview_assigns(assigns) do
    Map.merge(
      %{
        variant: :primary,
        size: :sm,
        width: nil,
        text_behavior: :default,
        muted: false,
        active: false,
        disabled: false,
        icon_position: :none
      },
      assigns
    )
  end

  defp normalize_button_assigns(assigns) do
    link_destinations =
      [assigns[:href], assigns[:navigate], assigns[:patch]]
      |> Enum.reject(&is_nil/1)

    if length(link_destinations) > 1 do
      raise ArgumentError,
            "Button.button/1 accepts only one of :href, :navigate, or :patch"
    end

    assigns
    |> assign_new(:muted, fn -> false end)
    |> assign_new(:active, fn -> false end)
    |> assign_new(:size, fn -> default_size(assigns.variant) end)
    |> assign_new(:width, fn -> nil end)
    |> assign_new(:text_behavior, fn -> :default end)
    |> assign_new(:disabled, fn -> false end)
    |> assign(:aria_expanded, aria_expanded_value(assigns))
    |> assign(:link_kind, link_kind(assigns))
  end

  defp link_kind(%{href: href}) when not is_nil(href), do: :href
  defp link_kind(%{navigate: navigate}) when not is_nil(navigate), do: :navigate
  defp link_kind(%{patch: patch}) when not is_nil(patch), do: :patch
  defp link_kind(_assigns), do: :button

  defp default_size(:primary), do: :sm
  defp default_size(:secondary), do: :sm
  defp default_size(:danger), do: :sm
  defp default_size(:text), do: :sm
  defp default_size(:pill), do: :sm
  defp default_size(:close), do: :sm

  defp base_classes(:close) do
    "group inline-flex size-5 items-center justify-center rounded-full transition focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
  end

  defp base_classes(:text) do
    "inline-flex max-w-full items-center justify-center gap-2 rounded-md bg-transparent font-bold shadow-none transition focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
  end

  defp base_classes(:pill) do
    "inline-flex max-w-full items-center justify-center gap-2 rounded-full font-semibold shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] transition focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
  end

  defp base_classes(_variant) do
    "inline-flex max-w-full items-center justify-center gap-2 rounded-md font-semibold shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] transition focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
  end

  defp size_classes(:close, _, _), do: ""
  defp size_classes(:pill, _, :wrap), do: "min-h-6 px-2 py-1 text-sm leading-4"
  defp size_classes(:pill, _, _), do: "h-6 px-2 py-1 text-sm leading-4"
  defp size_classes(:text, _, _), do: "py-1 text-sm leading-4"
  defp size_classes(_, :sm, :wrap), do: "min-h-8 px-6 py-1 text-sm leading-4"
  defp size_classes(_, :md, :wrap), do: "min-h-10 px-6 py-2 text-sm leading-4"
  defp size_classes(_, :sm, _), do: "h-8 px-6 text-sm leading-4"
  defp size_classes(_, :md, _), do: "h-10 px-6 text-sm leading-4"

  defp width_classes(nil, :default), do: "max-w-full"

  defp width_classes(nil, behavior) when behavior in [:wrap, :truncate],
    do: "w-[150px] max-w-full"

  defp width_classes(width, _behavior), do: width

  defp text_behavior_classes(:default), do: "block w-full text-center"

  defp text_behavior_classes(:wrap),
    do: "block w-full whitespace-normal break-words text-center"

  defp text_behavior_classes(:truncate),
    do: "block w-full overflow-hidden text-ellipsis whitespace-nowrap text-center"

  defp interaction_classes(true),
    do: "cursor-not-allowed focus-visible:outline-none"

  defp interaction_classes(false), do: "cursor-pointer"

  defp variant_classes(:primary, false, false),
    do:
      "bg-Fill-Buttons-fill-primary text-Text-text-white hover:bg-Fill-Buttons-fill-primary-hover"

  defp variant_classes(:primary, true, false),
    do:
      "bg-Fill-Buttons-fill-primary-muted text-Specially-Tokens-Text-text-button-muted hover:bg-Fill-Buttons-fill-primary-muted-hover hover:text-Text-text-white"

  defp variant_classes(:secondary, _muted, false),
    do:
      "border border-Border-border-bold bg-Background-bg-primary text-Specially-Tokens-Text-text-button-secondary hover:border-Border-border-bold-hover hover:bg-Surface-surface-secondary-hover hover:text-Specially-Tokens-Text-text-button-secondary-hover"

  defp variant_classes(:danger, _muted, false),
    do:
      "border border-Border-border-danger bg-transparent font-medium text-Specially-Tokens-Text-text-button-pill-muted hover:border-Border-border-danger-hover hover:bg-[rgba(255,64,64,0.16)]"

  defp variant_classes(:text, _muted, false),
    do: "text-Text-text-button hover:underline"

  defp variant_classes(:pill, false, false),
    do:
      "bg-Fill-Buttons-fill-primary text-Text-text-white hover:bg-Fill-Buttons-fill-primary-hover hover:text-Specially-Tokens-Text-text-button-primary-hover"

  defp variant_classes(:pill, true, false),
    do:
      "bg-Fill-Buttons-fill-primary-muted text-Specially-Tokens-Text-text-button-muted hover:bg-Fill-Buttons-fill-primary-muted-hover hover:text-Text-text-white"

  defp variant_classes(:primary, _muted, true),
    do:
      "bg-Fill-Buttons-fill-primary-muted text-Specially-Tokens-Text-text-button-muted shadow-none"

  defp variant_classes(:secondary, _muted, true),
    do: "border border-Text-text-low bg-Surface-surface-secondary text-Text-text-low shadow-none"

  defp variant_classes(:danger, _muted, true),
    do:
      "border border-Border-border-low bg-Surface-surface-secondary text-Text-text-low shadow-none"

  defp variant_classes(:text, _muted, true),
    do: "text-Text-text-low no-underline"

  defp variant_classes(:pill, _muted, true),
    do:
      "bg-Fill-Buttons-fill-primary-muted text-Specially-Tokens-Text-text-button-muted shadow-none"

  defp close_classes(true),
    do: "cursor-not-allowed opacity-60"

  defp close_classes(false),
    do: "cursor-pointer opacity-60 hover:opacity-100"

  defp close_icon_classes,
    do: "h-5 w-5"

  defp icon_classes, do: "h-4 w-4 stroke-current"

  defp preview_label, do: "Button label"

  defp aria_expanded_value(%{variant: :pill, active: active, rest: rest}),
    do: Map.get(rest, "aria-expanded", to_string(active))

  defp aria_expanded_value(%{rest: rest}), do: Map.get(rest, "aria-expanded")

  defp title_text(:truncate, nil, label_text), do: label_text
  defp title_text(:truncate, existing, _label_text), do: existing
  defp title_text(_behavior, existing, _label_text), do: existing

  defp aria_label_text(:truncate, nil, label_text), do: label_text
  defp aria_label_text(:truncate, existing, _label_text), do: existing
  defp aria_label_text(_behavior, existing, _label_text), do: existing

  defp close_title(nil, nil), do: "Close"
  defp close_title(nil, aria_label), do: aria_label
  defp close_title(existing, _aria_label), do: existing

  defp close_aria_label(nil), do: "Close"
  defp close_aria_label(existing), do: existing

  defp slot_plain_text(rendered_slot) do
    text =
      rendered_slot
      |> rendered_fragment_to_string()
      |> IO.iodata_to_binary()

    text
    |> then(&Regex.replace(~r/<[^>]*>/, &1, ""))
    |> String.trim()
  end

  defp rendered_fragment_to_string(nil), do: ""
  defp rendered_fragment_to_string(bin) when is_binary(bin), do: bin
  defp rendered_fragment_to_string({:safe, iodata}), do: IO.iodata_to_binary(iodata)

  defp rendered_fragment_to_string(%Phoenix.LiveView.Rendered{} = rendered),
    do: rendered |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()

  defp rendered_fragment_to_string(list) when is_list(list) do
    list
    |> Enum.map(&rendered_fragment_to_string/1)
    |> Enum.join("")
  end

  defp rendered_fragment_to_string(other), do: to_string(other)
end
