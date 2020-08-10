

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

  def setup(%{ publication: publication, skill_ids: skill_ids }) do
    objective_revs = Publishing.get_published_revisions(publication.id, skill_ids)

    # We noticed an issue where some skill resource IDs were not being found in the query.
    # We log instances of this issue.
    missing_skills = MapSet.difference(
      MapSet.new(skill_ids),
      MapSet.new(Enum.map(objective_revs, & &1.resource_id)))
    if !Enum.empty?(missing_skills)
    do
      Logger.error("Error finding objectives with resource ids #{Kernel.inspect(missing_skills)} and publication #{Kernel.inspect(publication)}")
    end

    objective_revs
    |> Enum.map(& element(:skill, [element(:name, &1.title)]))
  end

end
