

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

  def setup(%{ publication: publication, skill_ids: skill_ids }) do
    skill_ids
    |> Enum.map(& element(:skill, [make_skill_element(publication, &1)]))
  end

  defp make_skill_element(publication, skill_id) do
    element(:name, Publishing.get_published_revision(publication.id, skill_id).title)
  end

end
