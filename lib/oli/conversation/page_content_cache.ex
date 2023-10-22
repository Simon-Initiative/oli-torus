defmodule Oli.Converstation.PageContentCache do
  @moduledoc """
    Provides a cache that can be used for providing access to page content, based on
    page revision id.
  """

  @cache_name :page_content_cache

  def put(revision_id, content),
    do: Cachex.put(@cache_name, revision_id, content)

  def get(revision_id),
    do: Cachex.get(@cache_name, revision_id)
end
