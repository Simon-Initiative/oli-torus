defmodule Oli.Auditing.SnapshotTest do
  use ExUnit.Case, async: true

  alias Oli.Accounts.User
  alias Oli.Auditing.Snapshot

  doctest Snapshot

  test "keeps only allowlisted identity fields" do
    user = %User{
      id: 7,
      name: "Ada",
      email: "ada@example.edu",
      password_hash: "hash",
      given_name: "A"
    }

    assert Snapshot.of(user) == %{"id" => 7, "name" => "Ada", "email" => "ada@example.edu"}
  end

  test "accepts maps with string or atom keys and drops nil and complex values" do
    assert Snapshot.of(%{"title" => "Quiz", type: :graded, slug: nil, label: %{"x" => 1}}) ==
             %{"title" => "Quiz", "type" => "graded"}

    assert Snapshot.of(nil) == %{}
  end

  test "truncates long values" do
    assert Snapshot.of(%{title: String.duplicate("a", 300)})["title"] |> String.length() == 255
  end

  test "validates stored snapshots" do
    assert :ok = Snapshot.validate(%{"id" => 1, "name" => "Ada"})
    assert {:error, _} = Snapshot.validate(%{"password" => "x"})
    assert {:error, _} = Snapshot.validate(%{"name" => %{"nested" => true}})
    assert {:error, _} = Snapshot.validate(%{name: "atom key"})
    assert {:error, _} = Snapshot.validate("not a map")
    assert {:error, _} = Snapshot.validate(~D[2026-01-01])
    assert {:error, _} = Snapshot.validate(%{{1, 2} => "tuple key"})
    assert {:error, _} = Snapshot.validate(%{"name" => <<0xFF, 0xFE>>})
    assert {:error, _} = Snapshot.validate(%{"name" => String.duplicate("a", 256)})
  end

  test "search text uses identity values only, without duplicates" do
    assert Snapshot.search_text([
             %{"id" => 1, "name" => "Ada", "email" => "ada@example.edu"},
             %{"name" => "Ada", "title" => "Quiz"},
             %{"label" => "Intro Biology"}
           ]) == "Ada ada@example.edu Quiz Intro Biology"
  end
end
