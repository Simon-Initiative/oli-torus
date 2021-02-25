defmodule OliWeb.Common.DeliverySession do
  @moduledoc """
  Delivery session is a struct for managing a user's session data across possibly different
  platforms and course sections.

  For example:
  ```
  %{
    [platform_id]: %{
      user_id: number(),              # user identifier
      sections: %{
        [sections_slug]: string(),    # lti params key for a particular user and section
      }
    }
  }
  ```

  A plug will set lti_params in assigns using the user id and and lti_params if a section_slug is present in the url
  """
  import Plug.Conn
  import Oli.Utils, only: [value_or: 2]

  @delivery_session_key :delivery

  @doc """
  Puts the user_id for a particular platform in the delivery session
  """
  def put_user(conn, platform_id, user_id) do
    delivery_session = get_or_create_delivery_session(conn)

    delivery_session = delivery_session
      |> Map.put(platform_id,
        value_or(delivery_session[platform_id], %{})
        |> Map.put(:user_id, user_id)
      )

    conn
    |> put_session(@delivery_session_key, delivery_session)
  end

  @doc """
  Puts the lti params key for a particular user's section in the delivery session
  """
  def put_user_section_lti_params_key(conn, platform_id, section_slug, cache_key) do
    delivery_session = get_or_create_delivery_session(conn)

    delivery_session = delivery_session
      |> Map.put(platform_id,
        value_or(delivery_session[platform_id], %{})
        |> Map.put(:sections,
          value_or(delivery_session[platform_id][:sections], %{})
          |> Map.put(section_slug, cache_key)
        )
      )

    conn
    |> put_session(@delivery_session_key, delivery_session)
  end

  @doc """
  Gets the user for a particular platform from the delivery session
  """
  def get_user(conn, platform_id) do
    delivery_session = get_or_create_delivery_session(conn)

    delivery_session
    |> get_in([platform_id, :user_id])
  end

  @doc """
  Gets the lti params key for a particular user's section from the delivery session
  """
  def get_user_section_lti_params_key(conn, platform_id, section_slug) do
    delivery_session = get_or_create_delivery_session(conn)

    delivery_session
    |> get_in([platform_id, :sections, section_slug])
  end

  defp get_or_create_delivery_session(conn) do
    conn
    |> get_session(@delivery_session_key)
    |> value_or(%{})
  end

end
