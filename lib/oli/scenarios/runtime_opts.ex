defmodule Oli.Scenarios.RuntimeOpts do
  @moduledoc """
  Helper for building execution options for Oli.Scenarios so we reuse existing
  authors and institutions instead of creating throwaway records each run.
  """

  import Ecto.Query, only: [from: 2]

  alias Oli.Accounts.Author
  alias Oli.Institutions.Institution
  alias Oli.Repo

  def build(opts \\ []) do
    opts
    |> ensure(:author, &existing_author/0)
    |> ensure(:institution, &existing_institution/0)
  end

  defp ensure(opts, key, fetch_fun) do
    case Keyword.has_key?(opts, key) do
      true -> opts
      false -> maybe_put(opts, key, fetch_fun.())
    end
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp existing_author do
    Repo.one(from a in Author, limit: 1, order_by: [asc: a.id])
  end

  defp existing_institution do
    Repo.one(from i in Institution, limit: 1, order_by: [asc: i.id])
  end
end
