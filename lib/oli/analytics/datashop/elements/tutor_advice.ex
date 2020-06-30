
defmodule Oli.Analytics.Datashop.Elements.TutorAdvice do
  @moduledoc """
  <tutor_advice> Some useful information is highlighted in the problem statement. .</tutor_advice>
  """
  import XmlBuilder
  alias Oli.Analytics.Datashop.Utils

  def setup(%{ hint_text: hint_text }) do
    element(:tutor_advice, hint_text)
  end
end
