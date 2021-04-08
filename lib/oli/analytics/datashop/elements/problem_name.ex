defmodule Oli.Analytics.Datashop.Elements.ProblemName do
  @moduledoc """
  <problem_name>Activity slug, part 1</problem_name>
  """
  import XmlBuilder
  alias Oli.Analytics.Datashop.Utils

  def setup(%{activity_slug: activity_slug, part_id: part_id}) do
    element(:problem_name, Utils.make_problem_name(activity_slug, part_id))
  end

  def setup(%{name: name}) do
    element(:problem_name, name)
  end
end
