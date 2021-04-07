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
  alias Oli.Publishing
  require Logger

  def setup(%{publication: publication, skill_ids: skill_ids}) do
    skill_ids
    |> Enum.map(&element(:skill, [make_skill_element(publication, &1)]))
    |> Enum.filter(&(&1 != nil))
  end

  defp make_skill_element(publication, skill_id) do
    objective_rev = Publishing.get_published_revision(publication.id, skill_id)

    case objective_rev do
      nil ->
        Logger.error(
          "Error finding objective with resource id #{skill_id} and publication #{
            Kernel.inspect(publication)
          }"
        )

        nil

      _ ->
        element(:name, objective_rev.title)
    end
  end
end
