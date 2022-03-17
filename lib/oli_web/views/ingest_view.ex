defmodule OliWeb.IngestView do
  use OliWeb, :view

  import Oli.Interop.Ingest, only: [prettify_error: 1]
end
