defmodule Oli.Host.HostIdentifierTest do
  use Oli.DataCase
  alias Oli.Host.HostIdentifier
  alias Oli.Repo

  describe "changeset/2" do
    setup do
      Repo.delete_all(HostIdentifier)
      :ok
    end

    test "default id equals to 1" do
      params = %{hostname: "some_host"}

      host_identifier = %HostIdentifier{} |> HostIdentifier.changeset(params) |> apply_changes

      assert host_identifier.id == 1
    end

    test "validate required field" do
      params = %{}

      host_identifier = %HostIdentifier{} |> HostIdentifier.changeset(params)

      refute host_identifier.valid?
    end

    test "check constraint id to be 1" do
      params = %{id: 2, hostname: "some_host"}

      {:error, changeset} =
        %HostIdentifier{} |> HostIdentifier.changeset(params) |> Repo.insert()

      refute changeset.valid?

      assert changeset.errors == [
               id: {"must be 1", [constraint: :check, constraint_name: "one_row"]}
             ]
    end

    test "check constraint id must be unique" do
      params = %{hostname: "some_host"}
      %HostIdentifier{} |> HostIdentifier.changeset(params) |> Repo.insert!()

      params = %{id: 1, hostname: "some__other_host"}
      {:error, changeset} = %HostIdentifier{} |> HostIdentifier.changeset(params) |> Repo.insert()

      refute changeset.valid?

      assert changeset.errors == [
               id:
                 {"has already been taken",
                  [constraint: :unique, constraint_name: "host_identifier_id_index"]}
             ]
    end
  end
end
