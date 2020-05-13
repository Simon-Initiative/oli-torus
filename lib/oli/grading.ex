defmodule Oli.Grading do
  @moduledoc """
  Grading is responsible for compiling attempts into usable gradebook representation
  consumable by various tools such as Excel (CSV) or an LMS API
  """

  def export_csv() do

  end

  @doc """
  Returns a map-based representation of a table that contains all the grades for
  every registered user.
  """
  def compile_gradebook_for_section(section_id) do
    # get publication for the section

    # get publication page resources, filtered by graded: true

    # get students registered in the section, filter by role: student

    # for each user in the section, retrieve the latest attempt for every
    # graded resource. If an attempt doesnt exist, leave the value nil
    # TODO: adding grading policy config option (latest attempt, average, etc...)

    # return map of user grades
  end
end
