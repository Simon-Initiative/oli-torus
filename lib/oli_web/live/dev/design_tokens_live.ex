defmodule OliWeb.Dev.DesignTokensLive do
  @moduledoc """
  Dev-only catalog for shared design-tokens primitives.

  The catalog autodiscovers primitive modules under
  `OliWeb.Components.DesignTokens.Primitives` and renders their self-declared
  previews, variants, and Figma references.
  """

  use OliWeb, :live_view

  alias OliWeb.Common.React
  alias OliWeb.Icons

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       primitives: load_primitives(),
       selected_tab: "buttons",
       hide_header: true,
       hide_footer: true,
       ctx: %{is_liveview: true}
     )}
  end

  def handle_event("select_tab", %{"tab" => tab}, socket)
      when tab in ["buttons", "flash_messages"] do
    {:noreply, assign(socket, selected_tab: tab)}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-Surface-surface-primary p-10 text-Text-text-high">
      <div class="mb-8 flex flex-col gap-3">
        <div class="flex h-20 items-center justify-between">
          <div class="space-y-1">
            <h1 class="text-3xl font-semibold text-Text-text-high">Design Tokens</h1>
            <p class="text-lg text-Text-text-low">
              This page autodiscovers shared primitives under <code>OliWeb.Components.DesignTokens.Primitives</code>.
            </p>
          </div>
          {React.component(@ctx, "Components.DarkModeSelector", %{idPrefix: "dark_mode_selector"},
            id: "dark_mode_selector"
          )}
        </div>
        <p class="text-sm text-Text-text-low">
          Each primitive is responsible for exposing its own catalog metadata and dev preview.
        </p>
      </div>

      <div class="mb-8 flex items-center gap-2 border-b border-Border-border-subtle">
        <button
          type="button"
          phx-click="select_tab"
          phx-value-tab="buttons"
          class={tab_classes(@selected_tab == "buttons")}
          aria-pressed={to_string(@selected_tab == "buttons")}
        >
          Buttons
        </button>
        <button
          type="button"
          phx-click="select_tab"
          phx-value-tab="flash_messages"
          class={tab_classes(@selected_tab == "flash_messages")}
          aria-pressed={to_string(@selected_tab == "flash_messages")}
        >
          Flash Messages
        </button>
      </div>

      <%= if @selected_tab == "buttons" do %>
        <div class="space-y-8">
          <div class="flex items-start gap-3 rounded-xl border border-Border-border-subtle bg-Surface-surface-secondary p-4">
            <Icons.alert class="mt-0.5 h-5 w-5 shrink-0 fill-Icon-icon-warning" />
            <p class="text-sm text-Text-text-low">
              Disabled button states shown here were inferred in code and do not currently come from Figma. They should be validated by Jess before being treated as canonical design-system guidance.
            </p>
          </div>

          <div class="rounded-xl border border-Border-border-subtle bg-Surface-surface-secondary p-6">
            <div class="space-y-3">
              <h2 class="text-2xl font-semibold text-Text-text-high">API</h2>
              <p class="text-sm text-Text-text-low">
                `Button/Small-w-Icon` and similar labels are catalog groupings, not extra variants. In real HEEx usage you compose a button by choosing a `variant`, a `size`, optional attrs, and optional slots.
              </p>
              <div class="grid gap-4 md:grid-cols-2">
                <div class="space-y-2 rounded-lg border border-Border-border-subtle bg-Background-bg-primary p-4">
                  <p class="text-xs font-semibold uppercase tracking-wide text-Text-text-low-alpha">
                    Core attrs
                  </p>
                  <div class="space-y-2 text-sm text-Text-text-low">
                    <p>
                      <strong class="font-semibold text-Text-text-high">variant</strong>
                      <br />
                      <code>:primary | :secondary | :danger | :text | :pill | :close</code>
                      <br /> Default: <code>:primary</code>
                    </p>
                    <p>
                      <strong class="font-semibold text-Text-text-high">size</strong> <br />
                      <code>:sm | :md</code> <br /> Default: <code>:sm</code>
                    </p>
                    <p>
                      <strong class="font-semibold text-Text-text-high">text_behavior</strong> <br />
                      <code>:default | :wrap | :truncate</code> <br /> Default: <code>:default</code>
                    </p>
                    <p>
                      <strong class="font-semibold text-Text-text-high">disabled</strong> <br />
                      <code>true | false</code> <br /> Default: <code>false</code>
                    </p>
                    <p>
                      <strong class="font-semibold text-Text-text-high">muted</strong> <br />
                      <code>true | false</code> <br /> Default: <code>false</code>
                    </p>
                    <p>
                      <strong class="font-semibold text-Text-text-high">active</strong>
                      <br /> Meaningful for variant <code>:pill</code>
                      <br /> Default: <code>false</code>
                    </p>
                    <p>
                      <strong class="font-semibold text-Text-text-high">width</strong>
                      <br /> Optional class string<br /> Default: inferred by
                      <code>text_behavior</code>
                    </p>
                  </div>
                </div>
                <div class="space-y-2 rounded-lg border border-Border-border-subtle bg-Background-bg-primary p-4">
                  <p class="text-xs font-semibold uppercase tracking-wide text-Text-text-low-alpha">
                    Slots and Phoenix attrs
                  </p>
                  <div class="space-y-2 text-sm text-Text-text-low">
                    <p>
                      <strong class="font-semibold text-Text-text-high">Accepted slots</strong>
                      <br />
                      <code>:icon_left</code>, <code>:icon_right</code>, default label block
                    </p>
                    <p>
                      <strong class="font-semibold text-Text-text-high">Slot defaults</strong>
                      <br /> No icons unless a slot is provided
                    </p>
                    <p>
                      <strong class="font-semibold text-Text-text-high">Phoenix event attrs</strong>
                      <br /> Pass through directly: <code>phx-click</code>, <code>phx-target</code>,
                      <code>phx-value-*</code>
                    </p>
                    <p>
                      <strong class="font-semibold text-Text-text-high">Links vs buttons</strong>
                      <br /> Links use <code>href</code>
                      <br /> Buttons use native <code>type</code> and <code>disabled</code>
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div
            :for={primitive <- @primitives}
            class="rounded-xl border border-Border-border-subtle bg-Surface-surface-secondary p-6"
          >
            <div class="mb-5 flex items-start justify-between gap-4">
              <div class="space-y-1">
                <h2 class="text-2xl font-semibold text-Text-text-high">Examples</h2>
              </div>
              <a
                :if={primitive.catalog.figma_url}
                href={primitive.catalog.figma_url}
                target="_blank"
                rel="noreferrer"
                class="text-sm font-semibold text-Text-text-button hover:text-Text-text-button-hover hover:underline"
              >
                Open Figma
              </a>
            </div>

            <div class="space-y-5">
              <div :for={section <- primitive.catalog.sections} class="space-y-3">
                <h3 class="text-sm font-semibold uppercase tracking-wide text-Text-text-low-alpha">
                  {section.title}
                </h3>
                <.preview_surface>
                  <div class="space-y-5">
                    <div class="space-y-3">
                      <div class="text-xs font-semibold uppercase tracking-wide text-Text-text-low-alpha">
                        Enabled
                      </div>
                      <div class="flex flex-wrap items-start gap-4">
                        <%= for example <- Enum.reject(section.examples, &long_text_example?/1) do %>
                          <div class="flex w-56 flex-col gap-2">
                            <div class="flex min-h-10 items-start">
                              <span
                                class="block w-full truncate text-xs font-medium text-Text-text-low"
                                title={example.label}
                              >
                                {example.label}
                              </span>
                            </div>
                            <div class="flex h-16 items-start">
                              {apply(primitive.module, :preview, [example.assigns])}
                            </div>
                            <div class="relative w-full">
                              <button
                                id={"copy-enabled-#{slugify(section.title)}-#{slugify(example.label)}"}
                                type="button"
                                phx-hook="CopyToClipboard"
                                data-copy-text={button_code(example.assigns)}
                                class="absolute right-2 top-2 text-Text-text-low transition hover:text-Text-text-high"
                                title="Copy HEEx"
                              >
                                <Icons.clipboard class="h-4 w-4 fill-current" />
                              </button>
                              <pre class="w-full overflow-x-auto rounded-md border border-Border-border-subtle bg-Surface-surface-secondary-muted p-2 pt-8 text-[11px] leading-4 text-Text-text-low"><code>{button_code(example.assigns)}</code></pre>
                            </div>
                          </div>
                        <% end %>
                      </div>

                      <div class="text-xs font-semibold uppercase tracking-wide text-Text-text-low-alpha">
                        Disabled
                      </div>
                      <div class="flex flex-wrap items-start gap-4">
                        <%= for example <- Enum.reject(section.examples, &long_text_example?/1) do %>
                          <div class="flex w-56 flex-col gap-2">
                            <div class="flex min-h-10 items-start">
                              <span
                                class="block w-full truncate text-xs font-medium text-Text-text-low"
                                title={example.label}
                              >
                                {example.label}
                              </span>
                            </div>
                            <div class="flex h-16 items-start">
                              {apply(primitive.module, :preview, [
                                Map.put(example.assigns, :disabled, true)
                              ])}
                            </div>
                            <div class="relative w-full">
                              <button
                                id={"copy-disabled-#{slugify(section.title)}-#{slugify(example.label)}"}
                                type="button"
                                phx-hook="CopyToClipboard"
                                data-copy-text={
                                  button_code(Map.put(example.assigns, :disabled, true))
                                }
                                class="absolute right-2 top-2 text-Text-text-low transition hover:text-Text-text-high"
                                title="Copy HEEx"
                              >
                                <Icons.clipboard class="h-4 w-4 fill-current" />
                              </button>
                              <pre class="w-full overflow-x-auto rounded-md border border-Border-border-subtle bg-Surface-surface-secondary-muted p-2 pt-8 text-[11px] leading-4 text-Text-text-low"><code>{button_code(Map.put(example.assigns, :disabled, true))}</code></pre>
                            </div>
                          </div>
                        <% end %>
                      </div>
                    </div>

                    <div
                      :if={Enum.any?(section.examples, &long_text_example?/1)}
                      class="rounded-lg border border-Border-border-subtle bg-Surface-surface-secondary-muted p-4"
                    >
                      <div class="mb-3 space-y-1">
                        <p class="text-xs font-semibold tracking-wide text-Text-text-low-alpha">
                          Attribute `:text_behavior`
                        </p>
                        <p class="text-sm text-Text-text-low">
                          This attribute defines how the button handles long labels: by keeping the default free width, wrapping within a constrained width, or truncating with ellipsis. `:truncate` also derives `title` and `aria-label` automatically from the full label text.
                        </p>
                      </div>
                      <div class="flex flex-wrap items-start gap-4">
                        <%= for example <- Enum.filter(section.examples, &long_text_example?/1) do %>
                          <div class={[
                            "flex flex-col gap-2",
                            example.label in ["text_behavior={:wrap}", "text_behavior={:truncate}"] &&
                              "w-64"
                          ]}>
                            <div class="flex min-h-10 items-start">
                              <span
                                class="block w-full truncate text-xs font-medium text-Text-text-low"
                                title={example.label}
                              >
                                {example.label}
                              </span>
                            </div>
                            <div class={[
                              "flex h-16 items-start",
                              example.label in ["text_behavior={:wrap}", "text_behavior={:truncate}"] &&
                                "w-48"
                            ]}>
                              {apply(primitive.module, :preview, [example.assigns])}
                            </div>
                            <div class="relative w-full">
                              <button
                                id={"copy-text-behavior-#{slugify(section.title)}-#{slugify(example.label)}"}
                                type="button"
                                phx-hook="CopyToClipboard"
                                data-copy-text={button_code(example.assigns)}
                                class="absolute right-2 top-2 text-Text-text-low transition hover:text-Text-text-high"
                                title="Copy HEEx"
                              >
                                <Icons.clipboard class="h-4 w-4 fill-current" />
                              </button>
                              <pre class="w-full overflow-x-auto rounded-md border border-Border-border-subtle bg-Background-bg-primary p-2 pt-8 text-[11px] leading-4 text-Text-text-low"><code>{button_code(example.assigns)}</code></pre>
                            </div>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  </div>
                </.preview_surface>
              </div>
            </div>
          </div>
        </div>
      <% else %>
        <div class="rounded-xl border border-Border-border-subtle bg-Surface-surface-secondary p-6">
          <div class="space-y-2">
            <h2 class="text-2xl font-semibold text-Text-text-high">Flash Messages</h2>
            <p class="text-sm text-Text-text-low">
              Placeholder tab. Shared flash-message primitives can be added here once they are introduced under <code>design_tokens</code>.
            </p>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  slot :inner_block, required: true

  defp preview_surface(assigns) do
    ~H"""
    <div class="h-full rounded-xl border border-Border-border-default bg-Background-bg-primary p-4">
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp load_primitives do
    "lib/oli_web/components/design_tokens/primitives/**/*.ex"
    |> Path.wildcard()
    |> Enum.map(&module_from_path/1)
    |> Enum.filter(&Code.ensure_loaded?/1)
    |> Enum.filter(&function_exported?(&1, :catalog, 0))
    |> Enum.filter(&function_exported?(&1, :preview, 1))
    |> Enum.map(fn module -> %{module: module, catalog: apply(module, :catalog, [])} end)
    |> Enum.sort_by(fn %{catalog: catalog} -> catalog.name end)
  end

  defp module_from_path(path) do
    path
    |> String.trim_leading("lib/")
    |> String.trim_trailing(".ex")
    |> String.split("/")
    |> Enum.map(&Macro.camelize/1)
    |> Module.concat()
  end

  defp long_text_example?(%{label: label}),
    do:
      label in [
        "text_behavior={:default}",
        "text_behavior={:wrap}",
        "text_behavior={:truncate}"
      ]

  defp tab_classes(true) do
    "border-b-2 border-Border-border-bold px-4 py-3 text-sm font-semibold text-Text-text-high"
  end

  defp tab_classes(false) do
    "border-b-2 border-transparent px-4 py-3 text-sm font-semibold text-Text-text-low transition hover:text-Text-text-high"
  end

  defp slugify(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
  end

  defp button_code(assigns) do
    assigns = Map.new(assigns)
    label = Map.get(assigns, :label, "Button label")
    variant = Map.get(assigns, :variant, :primary)

    attrs =
      []
      |> maybe_attr("variant", inspect(variant), variant != :primary)
      |> maybe_attr(
        "size",
        inspect(Map.get(assigns, :size, :sm)),
        Map.get(assigns, :size, :sm) != :sm
      )
      |> maybe_attr(
        "text_behavior",
        inspect(Map.get(assigns, :text_behavior, :default)),
        Map.get(assigns, :text_behavior, :default) != :default
      )
      |> maybe_attr("muted", "true", Map.get(assigns, :muted, false))
      |> maybe_attr("active", "true", variant == :pill and Map.get(assigns, :active, false))
      |> maybe_attr("disabled", "true", Map.get(assigns, :disabled, false))
      |> Enum.join(" ")

    open_tag =
      if attrs == "" do
        "<Button.button>"
      else
        "<Button.button #{attrs}>"
      end

    cond do
      variant == :close ->
        if attrs == "", do: "<Button.button />", else: "<Button.button #{attrs} />"

      Map.get(assigns, :icon_position) == :left ->
        """
        #{open_tag}
          <:icon_left>
            <Icons.chevron_right class="h-4 w-4 stroke-current" />
          </:icon_left>
          #{label}
        </Button.button>
        """
        |> String.trim()

      Map.get(assigns, :icon_position) == :right and variant != :pill ->
        """
        #{open_tag}
          #{label}
          <:icon_right>
            <Icons.chevron_right class="h-4 w-4 stroke-current" />
          </:icon_right>
        </Button.button>
        """
        |> String.trim()

      variant == :pill ->
        """
        #{open_tag}
          #{label}
          <:icon_right>
            <Icons.chevron_#{if Map.get(assigns, :active, false), do: "up", else: "down"} class="h-4 w-4 stroke-current" />
          </:icon_right>
        </Button.button>
        """
        |> String.trim()

      true ->
        """
        #{open_tag}
          #{label}
        </Button.button>
        """
        |> String.trim()
    end
  end

  defp maybe_attr(attrs, name, value, true), do: attrs ++ ["#{name}={#{value}}"]
  defp maybe_attr(attrs, _name, _value, false), do: attrs
end
