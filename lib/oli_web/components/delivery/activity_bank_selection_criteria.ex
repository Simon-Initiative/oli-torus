defmodule OliWeb.Components.Delivery.ActivityBankSelectionCriteria do
  @moduledoc false

  use OliWeb, :html

  attr :rows, :list, default: []
  attr :helper_text, :string, default: nil
  attr :heading_id, :string, default: nil
  attr :heading_level, :integer, default: nil
  attr :heading_text, :string, default: "Selection criteria:"
  attr :empty_text, :string, default: "No criteria configured."

  def selection_criteria(assigns) do
    ~H"""
    <div class="flex flex-col gap-2" aria-labelledby={@heading_id}>
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

      <p
        :if={@helper_text}
        class="m-0 font-open-sans text-[14px] font-normal leading-5 text-Text-text-low"
      >
        {@helper_text}
      </p>

      <div :if={@rows != []} class="flex flex-col gap-2">
        <div :for={row <- @rows} class="flex flex-col gap-2">
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
end
