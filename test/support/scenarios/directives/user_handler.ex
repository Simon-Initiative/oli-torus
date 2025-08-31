defmodule Oli.Scenarios.Directives.UserHandler do
  @moduledoc """
  Handles user creation directives.
  """

  alias Oli.Scenarios.DirectiveTypes.UserDirective
  alias Oli.Scenarios.Engine
  alias Oli.Utils.Seeder.AccountsFixtures

  def handle(%UserDirective{name: name, type: type, email: email, given_name: given_name, family_name: family_name}, state) do
    try do
      user = case type do
        :author ->
          AccountsFixtures.author_fixture(%{
            email: email,
            given_name: given_name,
            family_name: family_name
          })
        
        :instructor ->
          AccountsFixtures.user_fixture(%{
            email: email,
            given_name: given_name,
            family_name: family_name,
            is_instructor: true
          })
        
        :student ->
          AccountsFixtures.user_fixture(%{
            email: email,
            given_name: given_name,
            family_name: family_name
          })
        
        _ ->
          raise "Unknown user type: #{type}"
      end
      
      # Store user in state
      new_state = Engine.put_user(state, name, user)
      
      # Update current author if this is an author
      new_state = if type == :author do
        %{new_state | current_author: user}
      else
        new_state
      end
      
      {:ok, new_state}
    rescue
      e ->
        {:error, "Failed to create user '#{name}': #{Exception.message(e)}"}
    end
  end
end