defmodule Oli.Scenarios.TestSupport do
  @moduledoc """
  Support module for running scenarios in test environment.
  Provides helper functions that use test fixtures.
  """

  alias Oli.Utils.Seeder.AccountsFixtures

  @doc """
  Executes scenarios with test fixtures for author and institution.
  """
  def execute_with_fixtures(directives) do
    # Use test fixtures for author and institution
    author = AccountsFixtures.author_fixture()

    {:ok, institution} =
      Oli.Institutions.create_institution(%{
        name: "Test Institution #{System.unique_integer([:positive])}",
        institution_email: "test@institution.edu",
        country_code: "US",
        institution_url: "http://test.institution.edu"
      })

    # Execute with the test fixtures
    Oli.Scenarios.execute(directives, author: author, institution: institution)
  end

  @doc """
  Executes a YAML file with test fixtures.
  """
  def execute_file_with_fixtures(yaml_path) do
    author = AccountsFixtures.author_fixture()

    {:ok, institution} =
      Oli.Institutions.create_institution(%{
        name: "Test Institution #{System.unique_integer([:positive])}",
        institution_email: "test@institution.edu",
        country_code: "US",
        institution_url: "http://test.institution.edu"
      })

    Oli.Scenarios.execute_file(yaml_path, author: author, institution: institution)
  end
end
