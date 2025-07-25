defmodule Oli.GenAI.Completions.Provider do

  @callback generate(
    messages :: [Oli.GenAI.Completions.Message.t()],
    functions :: [Oli.GenAI.Completions.Function.t()],
    registered_model :: Oli.GenAI.Completions.RegisteredModel.t())
    :: {:ok, String.t()} | {:error, String.t()}

  @callback stream(
    messages :: [Oli.GenAI.Completions.Message.t()],
    functions :: [Oli.GenAI.Completions.Function.t()],
    registered_model :: Oli.GenAI.Completions.RegisteredModel.t(),
    stream_fn :: (String.t() -> any())) :: {:ok, String.t()} | {:error, String.t()}

end
