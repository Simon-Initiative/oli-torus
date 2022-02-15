defmodule Oli.Interop.CustomActivities.FileRecord do
  alias Oli.Interop.CustomActivities.{RecordContext}

  import XmlBuilder

  def setup(%{
        context: context,
        date_created: date_created,
        file_name: file_name,
        guid: guid
      }) do
    element(
      :file_record,
      %{
        date_created: date_created,
        file_name: file_name,
        guid: guid
      },
      [
        RecordContext.setup(%{
          context: context
        })
      ]
    )
  end
end
