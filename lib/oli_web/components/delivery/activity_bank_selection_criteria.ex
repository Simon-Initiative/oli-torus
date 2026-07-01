defmodule OliWeb.Components.Delivery.ActivityBankSelectionCriteria do
  @moduledoc """
  Shared criteria rendering for instructor-facing Activity Bank Selection surfaces.

  This component is used both directly in LiveView and indirectly when preview pages serialize
  the same criteria block to HTML for the React-based preview card.
  """

  use OliWeb, :html

  attr :rows, :list, default: []
  attr :helper_text, :string, default: nil
  attr :heading_id, :string, default: nil
  attr :heading_level, :integer, default: nil
  attr :heading_text, :string, default: "Selection criteria:"
  attr :empty_text, :string, default: "No criteria configured."

  def selection_criteria(assigns) do
    assigns = Map.put(assigns, :helper_parts, helper_text_parts(assigns.helper_text))

    ~H"""
    <div class="flex flex-col" aria-labelledby={@heading_id}>
      <div
        :if={@heading_id}
        id={@heading_id}
        role="heading"
        aria-level={@heading_level}
        class="font-open-sans text-[14px] font-bold leading-4 text-Text-text-high"
      >
        {@heading_text}
      </div>
      <div
        :if={!@heading_id}
        class="font-open-sans text-[14px] font-bold leading-4 text-Text-text-high"
      >
        {@heading_text}
      </div>

      <div :if={@helper_parts} class="mb-4 mt-1.5 flex items-center gap-2 text-Text-text-low-alpha">
        <OliWeb.Icons.filter class="h-4 w-4 shrink-0 stroke-current" />
        <p class="m-0 font-open-sans text-[14px] font-normal leading-5">
          {@helper_parts.prefix}
          <strong class="font-semibold text-Text-text-low">
            {@helper_parts.emphasis}
          </strong>
          {@helper_parts.suffix}
        </p>
      </div>

      <div :if={@rows != []} class="flex flex-col gap-4">
        <div :for={row <- @rows} class="flex flex-col gap-[10px]">
          <div class="font-open-sans text-[14px] font-bold leading-4 text-Text-text-low-alpha">
            {row.label}:
          </div>
          <div class="min-h-[40px] w-full rounded-[6px] bg-Specially-Tokens-Fill-fill-input-focused px-[10px] py-2 font-open-sans text-[16px] font-semibold leading-6 text-Text-text-high">
            {Enum.join(row.values, ", ")}
          </div>
        </div>
      </div>

      <p
        :if={@rows == []}
        class="m-0 font-open-sans text-[14px] font-normal leading-5 text-Text-text-low"
      >
        {@empty_text}
      </p>
    </div>
    """
  end

  @doc """
  Renders the selection criteria block to an HTML string.

  This is used by instructor preview pages that embed the criteria markup into a client-owned
  preview payload while keeping the criteria presentation logic server-side.
  """
  def selection_criteria_html(rows, opts \\ []) do
    %{
      rows: rows,
      helper_text: Keyword.get(opts, :helper_text),
      heading_id: Keyword.get(opts, :heading_id),
      heading_level: Keyword.get(opts, :heading_level, 4),
      heading_text: Keyword.get(opts, :heading_text, "Selection criteria:"),
      empty_text: Keyword.get(opts, :empty_text, "No criteria configured.")
    }
    |> selection_criteria()
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  defp helper_text_parts("Activities must match all of the following.") do
    %{prefix: "Activities must match ", emphasis: "all", suffix: " of the following."}
  end

  defp helper_text_parts("Activities may match any of the following.") do
    %{prefix: "Activities may match ", emphasis: "any", suffix: " of the following."}
  end

  defp helper_text_parts(_helper_text), do: nil
end
