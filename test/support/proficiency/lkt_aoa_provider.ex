defmodule Oli.Test.Proficiency.LktAoaProvider do
  def estimates_for_scopes(section, user_ids, scopes, opts),
    do: {:ok, {:lkt_aoa, :scopes, section, user_ids, scopes, opts}}
end
