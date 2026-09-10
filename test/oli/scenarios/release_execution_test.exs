defmodule Oli.Scenarios.ReleaseExecutionTest do
  use Oli.DataCase

  alias Oli.Scenarios
  alias Oli.Scenarios.ReleaseExecution

  test "legacy execution still creates implicit ownership" do
    result = Scenarios.execute([])

    assert %Oli.Accounts.Author{} = result.state.current_author
    assert %Oli.Institutions.Institution{} = result.state.current_institution
  end

  test "release execution rejects a dependent directive before ownership" do
    path =
      write_yaml("""
      - project:
          name: forbidden
          title: Must Not Exist
      - institution:
          name: Too Late
          country_code: US
          institution_email: too-late@example.edu
          institution_url: https://example.edu
      """)

    result = ReleaseExecution.execute_file(path)

    assert [{_, message}] = result.errors
    assert message =~ "must establish an active author and institution"
    assert Scenarios.summarize(result).users_created == 0
    assert Scenarios.summarize(result).institutions_created == 0
    refute Oli.Repo.get_by(Oli.Institutions.Institution, name: "Too Late")
  end

  test "created references establish ownership" do
    suffix = System.unique_integer([:positive])

    path =
      write_yaml("""
      - user:
          name: release_author
          type: author
          email: release-author-#{suffix}@example.edu
          given_name: Release
          family_name: Author
      - institution:
          name: Release Institution #{suffix}
          country_code: US
          institution_email: release-#{suffix}@example.edu
          institution_url: https://example.edu
      - ownership:
          author: ref:release_author
          institution: ref:Release Institution #{suffix}
      """)

    result = ReleaseExecution.execute_file(path)

    assert result.errors == []
    assert result.state.current_author.email == "release-author-#{suffix}@example.edu"
    assert result.state.current_institution.name == "Release Institution #{suffix}"
  end

  test "restricted lookup rejects ambiguous and inactive records" do
    system_admin_id = Oli.Accounts.SystemRole.role_id().system_admin
    Oli.Utils.Seeder.AccountsFixtures.author_fixture(system_role_id: system_admin_id)
    Oli.Utils.Seeder.AccountsFixtures.author_fixture(system_role_id: system_admin_id)

    path =
      write_yaml("""
      - ownership:
          author: default_admin
          institution: default_institution
      """)

    result = ReleaseExecution.execute_file(path)
    assert [{_, "default_admin is ambiguous"}] = result.errors
  end

  test "configured defaults resolve one active author and institution" do
    author =
      Oli.Utils.Seeder.AccountsFixtures.author_fixture(
        system_role_id: Oli.Accounts.SystemRole.role_id().system_admin
      )

    {:ok, institution} =
      Oli.Institutions.create_institution(%{
        name: "Configured Institution",
        country_code: "US",
        institution_email: "configured@example.edu",
        institution_url: "https://example.edu"
      })

    previous = Application.get_env(:oli, :preview_qa_tools)

    Application.put_env(:oli, :preview_qa_tools,
      default_admin_email: author.email,
      default_institution_id: institution.id
    )

    on_exit(fn -> Application.put_env(:oli, :preview_qa_tools, previous) end)

    path =
      write_yaml("""
      - ownership:
          author: default_admin
          institution: default_institution
      """)

    result = ReleaseExecution.execute_file(path)
    assert result.errors == []
    assert result.state.current_author.id == author.id
    assert result.state.current_institution.id == institution.id
  end

  test "references reject missing and wrong-type authors" do
    missing = ownership_result("ref:missing", "default_institution")
    assert [{_, message}] = missing.errors
    assert message =~ "was not created before ownership selection"

    path =
      write_yaml("""
      - user:
          name: learner
          type: student
          email: wrong-type@example.edu
          given_name: Wrong
          family_name: Type
      - ownership:
          author: ref:learner
          institution: default_institution
      """)

    wrong_type = ReleaseExecution.execute_file(path)
    assert [{_, message}] = wrong_type.errors
    assert message =~ "inactive or has the wrong type"
  end

  test "restricted author lookup rejects locked authors" do
    author = Oli.Utils.Seeder.AccountsFixtures.author_fixture()

    author
    |> Ecto.Changeset.change(locked_at: DateTime.utc_now() |> DateTime.truncate(:second))
    |> Oli.Repo.update!()

    result = ownership_result("email:#{author.email}", "default_institution")
    assert [{_, "author email did not resolve to an active record"}] = result.errors
  end

  defp write_yaml(contents) do
    path =
      Path.join(System.tmp_dir!(), "release-scenario-#{System.unique_integer([:positive])}.yaml")

    File.write!(path, contents)
    on_exit(fn -> File.rm(path) end)
    path
  end

  defp ownership_result(author, institution) do
    write_yaml("""
    - ownership:
        author: #{author}
        institution: #{institution}
    """)
    |> ReleaseExecution.execute_file()
  end
end
