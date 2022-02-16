defmodule Oli.Interop.CustomActivities.Logging do

  import XmlBuilder
  alias Oli.Interop.CustomActivities.{Url}

  def setup(
        %{
          session_id: session_id,
          source_id: source_id,
          logging_url: logging_url
        }
      ) do
    element(
      :logging,
      %{
        session_id: session_id,
        source_id: source_id
      },
      [
        Url.setup(
          %{
            url_text: logging_url
          }
        )
      ]
    )
  end
end
