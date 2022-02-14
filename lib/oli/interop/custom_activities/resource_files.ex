defmodule Oli.Interop.CustomActivities.ResourceFiles do

  import XmlBuilder

  def setup(
        %{
          context: _context
        }
      ) do
    element(
      :resource_files
    )
  end
end
