defmodule Oli.Publishing.Updating.Types do
  defmacro __using__(_opts) do
    quote do
      @type id :: integer()
      @type index :: integer()
      @type id_at_index :: {id(), index()}

      @type change ::
              {:equal}
              | {:append, list(id())}
              | {:insert, list(id_at_index())}
              | {:remove, list(id())}
              | {:reorder}
              | {:other}
    end
  end
end
