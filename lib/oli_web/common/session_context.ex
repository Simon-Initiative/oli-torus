defmodule OliWeb.Common.SessionContext do
  @moduledoc """
  Session Context (`ctx`) is a common interface for both Conn-based static views and LiveViews.

  This module helps to bridge the interoperability gap between static views and LiveViews by
  providing a common abstraction that can be used in both types of views, as opposed to
  directly accessing Plug.Conn or LiveView.Socket.

  The SessionContext struct holds useful information such as the current user, timezone information
  and preferences, etc. When deciding whether to expand this struct, consider whether the data is
  commonly used across multiple nested components/views, or whether it is used in both static and
  LiveViews. If so, it may be a good candidate to add to the SessionContext struct, otherwise it may
  be better to add it to the conn/socket assigns directly via a plug.

  To ensure a view is compatible with either static rendered page or LiveView, use/replace
  all instances of conn or socket with this module, and optionally add any required data fields
  which can be initialized on the `SessionContext.init()` call when a view is instantiated.

  For any view that utilizes this functionality, be sure to call `SessionContext.init(...)` in either
  the static view's controller or LiveView's mount.

  The `init(conn_or_session)` function takes either a `conn` struct for static views or the `session` map
  in LiveViews. The result can then be passed in to a view via assigns.
  """

  alias Oli.Accounts.{User, Author}
  alias Oli.AccountLookupCache
  alias OliWeb.Common.FormatDateTime

  @enforce_keys [
    :browser_timezone,
    :local_tz,
    :author,
    :user,
    :is_liveview
  ]

  defstruct [
    :browser_timezone,
    :local_tz,
    :author,
    :user,
    :is_liveview
  ]

  @type t() :: %__MODULE__{
          browser_timezone: String.t(),
          local_tz: String.t(),
          author: Author.t(),
          user: User.t(),
          is_liveview: boolean()
        }

  def init() do
    %__MODULE__{
      browser_timezone: nil,
      local_tz: nil,
      author: nil,
      user: nil,
      is_liveview: false
    }
  end

  @doc """
  Initialize a SessionContext struct from a Plug.Conn struct. User or Author structs are loaded
  from the account lookup cache.
  """
  def init(%Plug.Conn{assigns: assigns} = conn) do
    browser_timezone = Plug.Conn.get_session(conn, "browser_timezone")

    author = Map.get(assigns, :current_author)
    user = Map.get(assigns, :current_user)

    %__MODULE__{
      browser_timezone: browser_timezone,
      local_tz: FormatDateTime.tz_preference_or_default(author, user, browser_timezone),
      author: author,
      user: user,
      is_liveview: false
    }
  end

  @doc """
  Initialize a SessionContext struct from a LiveView session map. If User or Author structs are
  given as options (previously loaded by set_user plug), they will be used instead of looking up
  the user/author from the session map and making a cache lookup/database call.
  """
  def init(%Phoenix.LiveView.Socket{assigns: assigns} = _socket, %{} = session, opts \\ []) do
    browser_timezone = Map.get(session, "browser_timezone")

    author = Map.get(assigns, :current_author)
    user = Map.get(assigns, :current_user)

    %__MODULE__{
      browser_timezone: browser_timezone,
      local_tz: FormatDateTime.tz_preference_or_default(author, user, browser_timezone),
      author: author,
      user: user,
      is_liveview: true
    }
  end
end
