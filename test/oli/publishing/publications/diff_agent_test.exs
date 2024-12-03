defmodule Oli.Publishing.Publications.DiffAgentTest do
  use Oli.DataCase

  alias Oli.Publishing.Publications.DiffAgent
  alias Oli.Publishing.Publications.PublicationDiffKey
  alias Oli.Publishing.Publications.PublicationDiff

  describe "DiffAgent" do
    test "cleanup expired diffs" do
      non_expired_key = %PublicationDiffKey{key: "not_expired"}

      DiffAgent.put(non_expired_key, %PublicationDiff{
        classification: :major,
        edition: 0,
        major: 1,
        minor: 0,
        changes: %{},
        from_pub: 0,
        all_links: [],
        to_pub: 1,
        created_at: Timex.now() |> Timex.subtract(Timex.Duration.from_days(4))
      })

      expired_key = %PublicationDiffKey{key: "expired"}

      DiffAgent.put(expired_key, %PublicationDiff{
        classification: :major,
        edition: 0,
        major: 1,
        minor: 0,
        changes: %{},
        from_pub: 0,
        to_pub: 1,
        all_links: [],
        created_at: Timex.now() |> Timex.subtract(Timex.Duration.from_days(11))
      })

      assert %PublicationDiff{} = DiffAgent.get(non_expired_key)
      assert %PublicationDiff{} = DiffAgent.get(expired_key)

      DiffAgent.cleanup_diff_store()

      assert %PublicationDiff{} = DiffAgent.get(non_expired_key)
      assert nil == DiffAgent.get(expired_key)
    end
  end
end
