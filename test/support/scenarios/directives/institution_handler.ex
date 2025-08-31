defmodule Oli.Scenarios.Directives.InstitutionHandler do
  @moduledoc """
  Handles institution creation directives.
  """

  alias Oli.Scenarios.DirectiveTypes.InstitutionDirective
  alias Oli.Scenarios.Engine

  def handle(%InstitutionDirective{name: name, country_code: country_code, institution_email: inst_email, institution_url: inst_url}, state) do
    try do
      {:ok, institution} = Oli.Institutions.create_institution(%{
        name: name,
        country_code: country_code,
        institution_email: inst_email,
        institution_url: inst_url
      })
      
      # Store institution in state
      new_state = Engine.put_institution(state, name, institution)
      
      # Optionally set as current institution
      new_state = %{new_state | current_institution: institution}
      
      {:ok, new_state}
    rescue
      e ->
        {:error, "Failed to create institution '#{name}': #{Exception.message(e)}"}
    end
  end
end