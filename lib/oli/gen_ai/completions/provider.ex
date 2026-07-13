defmodule Oli.GenAI.Completions.Provider do
  @type provider_opts :: [
          response_format: map(),
          temperature: number(),
          max_tokens: pos_integer()
        ]

  @callback generate(
              messages :: [Oli.GenAI.Completions.Message.t()],
              functions :: [Oli.GenAI.Completions.Function.t()],
              registered_model :: Oli.GenAI.Completions.RegisteredModel.t(),
              opts :: provider_opts()
            ) ::
              {:ok, map()} | {:error, String.t()}

  @callback stream(
              messages :: [Oli.GenAI.Completions.Message.t()],
              functions :: [Oli.GenAI.Completions.Function.t()],
              registered_model :: Oli.GenAI.Completions.RegisteredModel.t(),
              stream_fn :: (String.t() -> any())
            ) :: {:ok, String.t()} | {:error, String.t()}
end
