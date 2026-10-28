defmodule Oli.Test.Proficiency.NaiveProvider do
  def estimates_for_objectives(section, user_ids, objective_ids, opts),
    do: {:ok, {:naive, :objectives, section, user_ids, objective_ids, opts}}

  def estimates_for_scopes(section, user_ids, scopes, opts),
    do: {:ok, {:naive, :scopes, section, user_ids, scopes, opts}}

  def objective_aggregates(section, objective_ids, opts),
    do: {:ok, {:naive, :objective_aggregates, section, objective_ids, opts}}

  def scope_aggregates(section, scopes, opts),
    do: {:ok, {:naive, :scope_aggregates, section, scopes, opts}}
end
