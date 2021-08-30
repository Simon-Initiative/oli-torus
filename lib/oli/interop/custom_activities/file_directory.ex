defmodule Oli.Interop.CustomActivities.FileDirectory do

  import XmlBuilder

  def setup(
        %{
          context: context
        }
      ) do
    element(
      :file_directory
    )
  end
end
