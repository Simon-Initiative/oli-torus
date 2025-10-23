defmodule Oli.GoogleDocs.ActivityBuilder do
  @moduledoc """
  Behaviour implemented by Google Docs activity builders. Builders are
  responsible for turning a parsed custom element struct into a persisted
  activity revision, along with any warnings raised during the process.
  """

  @type build_result ::
          {:ok, struct()}
          | {:error, term(), list(map())}

  @callback supported?(struct()) :: boolean()
  @callback build(struct(), keyword()) :: build_result
end
