defmodule OliWeb.Common.LtiSession do
  @moduledoc """
  A module for managing a user's session data across possibly different
  platforms and course sections.

  For example:
  ```
  %{
    user_params: string(),        # latest lti params associated with this user from the most recent launch
    sections: %{
      [sections_slug]: string()   # lti params for a particular user and section
    }
  }
  ```

  A plug will set lti_params in assigns using the user id and and lti_params if a section_slug is present in the url
  """
  import Plug.Conn
  import Oli.Utils, only: [value_or: 2]

  @lti_session_key :lti_session

  @doc """
  Puts the user lti params key for a particular section
  """
  def put_user_params(conn, lti_params_key) do
    lti_session = value_or(get_session(conn, @lti_session_key), %{})

    conn
    |> put_session(@lti_session_key,
      lti_session
      |> Map.put(:user_params, lti_params_key)
    )
  end

  @doc """
  Gets the latest lti params key for a particular user from the lti session
  """
  def get_user_params(conn) do
    get_session(conn, @lti_session_key)
    |> value_or(%{})
    |> get_in([:user_params])
  end

end
