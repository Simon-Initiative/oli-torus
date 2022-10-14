defmodule Oli.Resources.Alternatives.UserSectionPreferenceStrategy do
  alias Oli.Resources.Alternatives.AlternativesStrategyContext
  alias Oli.Delivery.ExtrinsicState

  require Logger

  @behaviour Oli.Resources.Alternatives.AlternativesStrategy

  @doc """
  Selects the first alternative that matches a given user preference.

  If a preference is not set for a user, then the first alternative marked
  by 'default: true' is selected.

  If none of the alternatives are marked as default, then the first alternative
  is selected.

  In the rare case when there are no alternatives set, this will return an empty list `[]]`.
  """
  def select(
        %AlternativesStrategyContext{user: user, section_slug: section_slug},
        %{
          "children" => children,
          "preference_name" => preference_name,
          "default" => default
        }
      ) do
    pref_key = ExtrinsicState.Key.alternatives_preference(preference_name)

    case ExtrinsicState.read_section(
           user.id,
           section_slug,
           MapSet.new([pref_key])
         ) do
      {:ok, %{^pref_key => pref}} ->
        Enum.find(children, fn alt -> alt["value"] == pref end)
        |> case do
          nil ->
            Logger.error(
              "Alternatives user preference '#{pref}' did not match any of the alternative values"
            )

            select_default(children, default)

          found ->
            [found]
        end

      _ ->
        select_default(children, default)
    end
  end

  def select_default(children, default) do
    Enum.find(children, fn alt -> alt["value"] == default end)
    |> case do
      nil ->
        Logger.error(
          "Alternatives default '#{default}' did not match any of the alternative values"
        )

        select_first(children)

      found ->
        [found]
    end
  end

  def select_first(children) do
    case Enum.at(children, 0) do
      nil ->
        Logger.error("Alternatives element does not have any alternatives specified")
        []

      first ->
        [first]
    end
  end
end
