defmodule OliWeb.Common.SessionContext do
  @moduledoc """
  Session Context related information
  """

  alias Oli.Accounts
  alias Oli.Accounts.Author
  alias Oli.Accounts.User

  @enforce_keys [
    :local_tz,
    :author,
    :user
  ]

  @default_timezone "Etc/UTC"

  defstruct [
    :local_tz,
    :author,
    :user
  ]

  @type t() :: %__MODULE__{
          local_tz: String.t(),
          author: Author.t(),
          user: User.t()
        }

  def init() do
    %__MODULE__{
      local_tz: nil,
      author: nil,
      user: nil
    }
  end

  def init(%Plug.Conn{assigns: assigns} = conn) do
    local_tz = Plug.Conn.get_session(conn, "local_tz") || @default_timezone
    author = Map.get(assigns, :current_author)
    user = Map.get(assigns, :current_user)

    %__MODULE__{
      local_tz: local_tz,
      author: author,
      user: user
    }
  end

  def init(%{} = session) do
    local_tz = Map.get(session, "local_tz", @default_timezone)

    author =
      case Map.get(session, "current_author_id") do
        nil ->
          nil

        author_id ->
          Accounts.get_author!(author_id)
      end

    user =
      case Map.get(session, "current_user_id") do
        nil ->
          nil

        user_id ->
          Accounts.get_user!(user_id)
      end

    %__MODULE__{
      local_tz: local_tz,
      author: author,
      user: user
    }
  end
end
