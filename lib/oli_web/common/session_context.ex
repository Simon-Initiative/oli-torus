defmodule OliWeb.Common.SessionContext do
  @moduledoc """
  Session Context is a common interface for both Conn-based static views and LiveViews.

  This module help bridge the interoperability gap between static views and LiveViews by
  providing a common abstraction that can be used in both types of views, as opposed to
  directly accessing Plug.Conn or LiveView.Socket.

  To ensure a view is compatible with either static rendered page or LiveView, use/replace
  all instances of conn or socket with this module, and optionally add any required data fields
  which can be initialized on the `SessionContext.init()` call when a view is instantiated.

  For any view that utilizes this functionality, be sure to call `SessionContext.init(...)` in either
  the static view's controller or LiveView's mount.

  The `init(conn_or_session)` function takes either a `conn` struct for static views or the `session` map
  in LiveViews. The result can then be passed in to a view via assigns.
  """

  alias Oli.Accounts
  alias Oli.Accounts.Author
  alias Oli.Accounts.User
  alias OliWeb.Common.FormatDateTime

  @enforce_keys [
    :local_tz,
    :author,
    :user
  ]

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
    browser_timezone =
      Plug.Conn.get_session(conn, "browser_timezone") || FormatDateTime.default_timezone()

    author = Map.get(assigns, :current_author)
    user = Map.get(assigns, :current_user)

    %__MODULE__{
      local_tz: local_tz(author, user, browser_timezone),
      author: author,
      user: user
    }
  end

  def init(%{} = session) do
    browser_timezone = Map.get(session, "browser_timezone", FormatDateTime.default_timezone())

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
      local_tz: local_tz(author, user, browser_timezone),
      author: author,
      user: user
    }
  end

  defp local_tz(author, user, browser_timezone) do
    cond do
      not is_nil(author) ->
        Accounts.get_author_preference(author, :timezone, browser_timezone)

      not is_nil(user) ->
        Accounts.get_user_preference(user, :timezone, browser_timezone)

      true ->
        browser_timezone
    end
  end
end
