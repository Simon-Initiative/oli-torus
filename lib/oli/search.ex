defmodule Oli.Search do

  def semantic_search(input) do


    Oli.Embeddings.search(input)

  end


end
