defmodule OliWeb.Components.DesignTokens.Primitives.Badge do
  @moduledoc """
  Shared identification-tag primitive for course-builder source cards.

  Renders the "Template" / "My Section" identification tag used to distinguish
  source kinds in the course-builder card grid (`OliWeb.Common.CardListing`).
  This is distinct from the existing cost badge (`TableModel.render_payment_column/3`,
  "Free"/price) — the two labels are independent and can appear on the same card.

  The `:template` variant's color is an interim choice (no confirmed Figma
  reference exists for it as of 2026-09-18); see
  `docs/exec-plans/current/epics/course_replication/course_builder_sources/informal.md`.
  It reuses the same `Fill-Accent-fill-accent-*` / `Text-text-accent-*` token
  family as `:my_section` (purple) for visual consistency with the rest of the
  accent-tag set, using the orange pair instead of a gray fill + border — no
  border is needed since the accent-orange fill/text pairing already meets
  contrast on its own, matching how `:my_section` is styled. Should still be
  revisited once design confirms a final color for this tag.
  """

  use Phoenix.Component

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
      name: "Badge",
      description: "Identification tag for course-builder source cards (Template / My Section).",
      figma_url:
        "https://www.figma.com/design/ZAfwBt1ek94xAyriR6wy8S/Course-replication-feature?node-id=44-789",
      sections: [
        %{
          title: "Badge/Variants",
          examples: [
            %{label: "My Section", assigns: %{variant: :my_section}},
            %{label: "Template", assigns: %{variant: :template}},
            %{label: "None", assigns: %{variant: nil}}
          ]
        }
      ]
    }
  end

  @doc """
  Render a representative preview for the dev design-tokens catalog.
  """
  def preview(assigns) do
    assigns = Map.new(assigns) |> Map.put_new(:variant, :my_section)

    ~H"""
    <.badge variant={@variant} />
    """
  end

  attr :variant, :atom, values: [:my_section, :template, nil], default: nil

  @doc """
  Render the identification tag, or nothing when `variant` is `nil`.
  """
  def badge(assigns) do
    ~H"""
    <span
      :if={@variant}
      class={[
        "inline-flex w-fit items-center rounded px-2 py-1 text-sm font-bold leading-none",
        variant_classes(@variant)
      ]}
    >
      {label(@variant)}
    </span>
    """
  end

  defp label(:my_section), do: "My Section"
  defp label(:template), do: "Template"

  defp variant_classes(:my_section),
    do: "bg-Fill-Accent-fill-accent-purple text-Text-text-accent-purple"

  defp variant_classes(:template),
    do: "bg-Fill-Accent-fill-accent-orange text-Text-text-accent-orange"
end
