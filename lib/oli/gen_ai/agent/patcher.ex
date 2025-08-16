defmodule Oli.GenAI.Agent.Patcher do
  @moduledoc "Applies approved drafts to Torus revisions transactionally."

  @spec apply_draft(draft_id :: String.t(), user :: map()) :: {:ok, term} | {:error, term}
  def apply_draft(_draft_id, _user), do: raise("TODO")

  @spec apply_many(draft_ids :: [String.t()], user :: map()) ::
          %{applied: [String.t()], failed: [{String.t(), term}]}
  def apply_many(_ids, _user), do: raise("TODO")
end