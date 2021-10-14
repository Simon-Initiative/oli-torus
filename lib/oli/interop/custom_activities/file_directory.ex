defmodule Oli.Interop.CustomActivities.FileDirectory do

  import XmlBuilder

  alias Oli.Interop.CustomActivities.{FileRecord}

  def setup(
        %{
          context: context
        }
      ) do
    children = fetchChildren(context)
    element(
      :file_directory,
      children
    )
  end

  defp fetchChildren(context) do
    children = []
    case context.save_file do
      nil -> children
      _ -> children ++ [FileRecord.setup(%{
        context: context
      })]
    end
  end
end
