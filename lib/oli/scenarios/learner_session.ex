defmodule Oli.Scenarios.LearnerSession do
  @moduledoc "Creates the DataShop session identifier used by a simulated learner."

  @doc "Builds one stable UUID for a learner's complete section simulation."
  def deterministic_id(seed, learner_identity, section_identity) do
    name =
      inspect({:oli_scenario_datashop_session, seed, learner_identity, section_identity},
        limit: :infinity
      )

    UUID.uuid5(:oid, name)
  end

  @doc "Creates a UUID for a lower-level directive without a simulation session."
  def transient_id, do: UUID.uuid4()
end
