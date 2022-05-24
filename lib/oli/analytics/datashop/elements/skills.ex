defmodule Oli.Analytics.Datashop.Elements.Skills do
  @moduledoc """
  <skill>
    <name>objective one</name>
  </skill>
  <skill>
    <name>objective two</name>
  </skill>
  """
  import XmlBuilder
  require Logger

  def setup(%{skill_ids: skill_ids, skill_titles: skill_titles}) do
    skill_ids
    |> Enum.map(&element(:skill, [make_skill_element(skill_titles, &1)]))
    |> Enum.filter(&(&1 != nil))
  end

  defp make_skill_element(skill_titles, skill_id) do
    case Map.get(skill_titles, skill_id) do
      nil ->
        Logger.error("Error finding objective with resource id #{skill_id}")

        nil

      title ->
        element(:name, title)
    end
  end
end
