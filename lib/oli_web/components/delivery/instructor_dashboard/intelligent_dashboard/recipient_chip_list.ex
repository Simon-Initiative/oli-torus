defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.RecipientChipList do
  use Phoenix.Component

  alias OliWeb.Icons

  attr :id, :string, required: true
  attr :recipients, :list, required: true
  attr :excluded, :list, default: []
  attr :target, :any, required: true
  attr :remove_event, :string, default: "remove_recipient"

  def recipient_chip_list(assigns) do
    assigns =
      assigns
      |> assign(:excluded_count, length(assigns.excluded))
      |> assign(:excluded_names, excluded_names(assigns.excluded))

    ~H"""
    <div class="space-y-1">
      <span id={"#{@id}_label"} class="text-sm font-semibold leading-4 text-Text-text-low-alpha">
        To:
      </span>
      <div
        aria-labelledby={"#{@id}_label"}
        role="group"
        class="min-h-[40px] w-full rounded-[6px] border border-Border-border-default bg-Specially-Tokens-Fill-fill-input px-4 py-2"
      >
        <div
          id={@id}
          phx-hook="OverflowChipList"
          class="flex items-center gap-1 overflow-hidden whitespace-nowrap"
        >
          <%= for student <- @recipients do %>
            <div
              data-overflow-chip
              class="inline-flex shrink-0 items-center gap-1 rounded-[12px] border border-Border-border-default bg-Specially-Tokens-Fill-fill-detail-pill px-2 py-1"
            >
              <button
                type="button"
                phx-click={@remove_event}
                phx-target={@target}
                phx-value-student_id={student.id}
                class="inline-flex h-4 w-4 items-center justify-center text-Text-text-high"
                aria-label={"Recipient: #{student.email}, remove"}
              >
                <Icons.close_sm class="h-4 w-4 stroke-current" />
              </button>
              <span
                class="max-w-[220px] truncate text-sm font-semibold leading-4 text-Text-text-high"
                title={student.email}
              >
                {student.email}
              </span>
            </div>
          <% end %>
          <button
            type="button"
            data-overflow-toggle
            class="hidden shrink-0 items-center rounded-[12px] border border-Border-border-default bg-Specially-Tokens-Fill-fill-detail-pill px-3 py-1 text-sm font-semibold leading-4 text-Text-text-high"
            aria-controls={@id}
            aria-expanded="false"
            aria-label="Show all recipients"
          >
            ...
          </button>
        </div>
      </div>
      <p
        :if={@recipients == []}
        class="text-sm leading-5 text-Text-text-low-alpha"
      >
        No students currently need this message. You can review the draft, but sending stays disabled until at least one recipient is available.
      </p>
      <p
        :if={@excluded_count > 0}
        class="text-sm leading-5 text-Text-text-low-alpha"
      >
        <span
          class="cursor-pointer underline decoration-dotted underline-offset-2"
          title={@excluded_names}
          aria-label={@excluded_names}
          tabindex="0"
        >
          {excluded_subject(@excluded_count)}
        </span>
        <span>
          {excluded_suffix(@excluded_count, @recipients)}
        </span>
      </p>
    </div>
    """
  end

  defp excluded_subject(1), do: "1 selected student"
  defp excluded_subject(count), do: "#{count} selected students"

  defp excluded_suffix(1, []), do: " does not have an associated email."
  defp excluded_suffix(_count, []), do: " do not have associated email addresses."

  defp excluded_suffix(1, _),
    do: " does not have an associated email and will not receive this message."

  defp excluded_suffix(_count, _),
    do: " do not have associated email addresses and will not receive this message."

  # Show at most this many names before collapsing the rest into a count, so the
  # title/aria-label stays usable (a screen reader reading hundreds of names is a
  # WCAG failure) and the assign/DOM attribute stays small.
  @max_excluded_names 3

  defp excluded_names(excluded) do
    shown = excluded |> Enum.take(@max_excluded_names) |> Enum.map(&excluded_display_name/1)

    case length(excluded) - length(shown) do
      0 ->
        Enum.join(shown, ", ")

      others ->
        "#{Enum.join(shown, ", ")}, and #{others} #{if others == 1, do: "other", else: "others"}"
    end
  end

  defp excluded_display_name(student) do
    case Map.get(student, :display_name) do
      name when is_binary(name) ->
        case String.trim(name) do
          "" -> "Unknown student"
          trimmed -> trimmed
        end

      _ ->
        "Unknown student"
    end
  end
end
