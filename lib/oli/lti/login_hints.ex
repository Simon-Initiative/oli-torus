defmodule Oli.Lti.LoginHints do
  @moduledoc """
  Domain operations for LTI login hints.
  """

  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Lti_1p3.DataProviders.EctoProvider.LoginHint

  require Logger

  @doc """
  Consumes a login hint value so it cannot be reused.

  This is a best-effort operation to avoid breaking successful launches in the
  unlikely event of a cleanup failure.
  """
  @spec consume(String.t()) :: :ok
  def consume(login_hint_value) when is_binary(login_hint_value) do
    from(h in LoginHint, where: h.value == ^login_hint_value)
    |> Repo.delete_all()

    :ok
  rescue
    e ->
      Logger.error(
        "Failed to consume login_hint #{login_hint_value}: #{Exception.format(:error, e, __STACKTRACE__)}"
      )

      :ok
  end

  def consume(_), do: :ok
end
