defmodule Oli.Scenarios.Directives.BulkCreateEnrollUsersHandler do
  @moduledoc "Executes the bulk_create_enroll_users scenario directive."

  alias Oli.Scenarios.BulkCreateEnrollUsers
  alias Oli.Scenarios.DirectiveTypes.BulkCreateEnrollUsersDirective
  alias Oli.Scenarios.Engine

  @doc "Creates and enrolls a cohort using the current seed account defaults."
  def handle(%BulkCreateEnrollUsersDirective{} = directive, state) do
    with section when not is_nil(section) <- Engine.get_section(state, directive.section),
         {:ok, users, result} <-
           BulkCreateEnrollUsers.create_and_enroll(section, directive, state.preview_demo_account) do
      {:ok,
       state
       |> Map.update!(:users, &Map.merge(&1, users))
       |> Map.update!(:scenario_results, &Map.put(&1, :bulk_create_enroll_users, result))}
    else
      nil -> {:error, "Section '#{directive.section}' not found"}
      {:error, reason} -> {:error, "bulk_create_enroll_users failed: #{inspect(reason)}"}
    end
  end
end
