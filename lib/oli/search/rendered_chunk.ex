defmodule Oli.Search.RenderedChunk do

  defstruct [
    :component_type,
    :chunk_type,
    :chunk_ordinal,
    :content,
    :fingerprint_md5
  ]

  def new([component_type: component_type, chunk_type: chunk_type, chunk_ordinal: chunk_ordinal, content: content]) do
    %__MODULE__{
      component_type: component_type
      chunk_type: chunk_type,
      chunk_ordinal: chunk_ordinal,
      content: content,
      fingerprint_md5: :erlang.md5(content)
    }
  end

end
