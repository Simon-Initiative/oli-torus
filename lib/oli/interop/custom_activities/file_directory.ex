defmodule Oli.Interop.CustomActivities.FileDirectory do
  import XmlBuilder

  alias Oli.Interop.CustomActivities.{FileRecord}

  def setup(%{
        context: context
      }) do

    children = fetchChildren(context)
    element(
      :file_directory,
      children
    )
  end

  defp fetchChildren(context) do
    case context.save_files do
      nil ->
        []
      save_files ->
        [
          save_files
          |> Enum.map(fn save_file ->
            FileRecord.setup(%{
              context: context,
              date_created: DateTime.to_unix(save_file.inserted_at),
              file_name: save_file.file_name,
              guid: save_file.file_guid
            })
          end)
        ]
    end
  end
end
