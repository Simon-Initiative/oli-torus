
defmodule Oli.Analytics.Datashop.Elements.SemanticEvent do
  @moduledoc """
  <semantic_event transaction_id="mary-smith-MAJOR-ARC-BFD-2-0-2006-07-22-12-55-00-004s" name="HINT_REQUEST"/>

  <semantic_event transaction_id="student-p1-MAJOR-ARC-BFD-2-0-2006-07-22-12-55-00-003s" name="ATTEMPT"/>
  """
  import XmlBuilder

  def setup(%{ transaction_id: transaction_id, name: name }) do
    element(:semantic_event, %{
      transaction_id: transaction_id,
      name: name
    })
  end
end
