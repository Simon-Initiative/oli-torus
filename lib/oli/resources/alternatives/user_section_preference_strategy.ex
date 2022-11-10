defmodule Oli.Resources.Alternatives.UserSectionPreferenceStrategy do
  alias Oli.Resources.Alternatives.AlternativesStrategyContext
  alias Oli.Delivery.ExtrinsicState
  alias Oli.Resources.Alternatives.Selection

  require Logger

  @behaviour Oli.Resources.Alternatives.AlternativesStrategy

  @doc """
  Selects the first alternative that matches a given user preference.

  If a preference is not set for a user, then the first alternative is selected.

  In the rare case when there are no alternatives set, this will return an empty list `[]]`.
  """
  def select(
        %AlternativesStrategyContext{user: user, section_slug: section_slug, mode: :delivery},
        %{
          "children" => children,
          "alternatives_id" => alternatives_id
        }
      ) do
    pref_key = ExtrinsicState.Key.alternatives_preference(alternatives_id)

    case ExtrinsicState.read_section(
           user.id,
           section_slug,
           MapSet.new([pref_key])
         ) do
      {:ok, %{^pref_key => pref}} ->
        # return all children with display: :none except for the alternative that matches the selected preference
        Enum.map(children, fn alt ->
          if alt["value"] == pref do
            %Selection{alternative: alt}
          else
            %Selection{alternative: alt, hidden: true}
          end
        end)

      _ ->
        display_first(children)
    end
  end

  def select(_, %{"children" => children}), do: display_first(children)

  defp display_first(children) do
    case children do
      [] ->
        Logger.error("Alternatives element does not have any alternatives specified")
        []

      [first | rest] ->
        [
          %Selection{alternative: first}
          | Enum.map(rest, fn alt -> %Selection{alternative: alt, hidden: true} end)
        ]
    end
  end
end
