defmodule OliWeb.LegacySupportController do
  use OliWeb, :controller
  alias Oli.Interop.LegacySupport

  def index(conn, _) do
    summary = %{
      resources: LegacySupport.resources(),
      supported: LegacySupport.supported(),
      converted: LegacySupport.converted(),
      unsupported: LegacySupport.unsupported(),
      pending: LegacySupport.pending()
    }

    json(conn, summary)
  end
end
