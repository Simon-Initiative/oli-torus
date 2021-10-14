defmodule Oli.Interop.CustomActivities.FileRecord do

  alias Oli.Interop.CustomActivities.{RecordContext}

  import XmlBuilder

  def setup(
        %{
          context: context
        }
      ) do
    element(
      :file_record,
      %{
        date_created: DateTime.to_unix(context.save_file.inserted_at),
        file_name: context.save_file.file_name,
        guid: context.save_file.file_guid
      },
      [
        RecordContext.setup(
          %{
            context: context
          }
        )
      ]
    )
  end
end
