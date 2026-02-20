defmodule OliWeb.Accounts.Masquerade do
  @moduledoc """
  Session-backed masquerade contract used by the web layer.
  """

  import Plug.Conn

  alias Oli.Accounts
  alias Oli.Accounts.{Author, User}

  @session_keys [
    :masquerade_active,
    :masquerade_subject_type,
    :masquerade_subject_id,
    :masquerade_subject_name,
    :masquerade_subject_email,
    :masquerade_admin_author_id,
    :masquerade_started_at,
    :masquerade_original_author_token,
    :masquerade_original_current_author_id,
    :masquerade_original_author_live_socket_id,
    :masquerade_original_user_token,
    :masquerade_original_current_user_id,
    :masquerade_target_user_token
  ]
  @string_to_atom_keys %{
    "masquerade_active" => :masquerade_active,
    "masquerade_subject_type" => :masquerade_subject_type,
    "masquerade_subject_id" => :masquerade_subject_id,
    "masquerade_subject_name" => :masquerade_subject_name,
    "masquerade_subject_email" => :masquerade_subject_email,
    "masquerade_admin_author_id" => :masquerade_admin_author_id,
    "masquerade_started_at" => :masquerade_started_at,
    "masquerade_original_author_token" => :masquerade_original_author_token,
    "masquerade_original_current_author_id" => :masquerade_original_current_author_id,
    "masquerade_original_author_live_socket_id" => :masquerade_original_author_live_socket_id,
    "masquerade_original_user_token" => :masquerade_original_user_token,
    "masquerade_original_current_user_id" => :masquerade_original_current_user_id,
    "masquerade_target_user_token" => :masquerade_target_user_token
  }

  @type masquerade_subject :: %{type: :user, id: integer}
  @type masquerade_payload :: %{
          active: true,
          subject_type: :user,
          subject_id: integer,
          subject_name: String.t() | nil,
          subject_email: String.t() | nil,
          admin_author_id: integer,
          started_at: String.t() | nil
        }

  @spec start(Plug.Conn.t(), Author.t(), User.t()) ::
          {:ok, Plug.Conn.t(), map()} | {:error, atom()}
  def start(conn, %Author{id: admin_author_id}, %User{} = target_user) do
    case active?(get_session(conn)) do
      true ->
        {:error, :already_active}

      false ->
        target_user_token = Accounts.generate_user_session_token(target_user)
        started_at = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
        author_live_socket_id = get_session(conn, :author_live_socket_id)

        if is_binary(author_live_socket_id) do
          OliWeb.Endpoint.broadcast(author_live_socket_id, "disconnect", %{})
        end

        conn =
          conn
          |> put_session(:masquerade_active, true)
          |> put_session(:masquerade_subject_type, "user")
          |> put_session(:masquerade_subject_id, target_user.id)
          |> put_session(:masquerade_subject_name, target_user.name)
          |> put_session(:masquerade_subject_email, target_user.email)
          |> put_session(:masquerade_admin_author_id, admin_author_id)
          |> put_session(:masquerade_started_at, started_at)
          |> put_session(:masquerade_original_author_token, get_session(conn, :author_token))
          |> put_session(
            :masquerade_original_current_author_id,
            get_session(conn, :current_author_id)
          )
          |> put_session(
            :masquerade_original_author_live_socket_id,
            author_live_socket_id
          )
          |> put_session(:masquerade_original_user_token, get_session(conn, :user_token))
          |> put_session(
            :masquerade_original_current_user_id,
            get_session(conn, :current_user_id)
          )
          |> put_session(:masquerade_target_user_token, target_user_token)
          |> delete_session(:author_token)
          |> delete_session(:current_author_id)
          |> delete_session(:author_live_socket_id)
          |> put_session(:user_token, target_user_token)
          |> put_session(:current_user_id, target_user.id)

        {:ok, conn,
         %{
           subject_type: :user,
           subject_id: target_user.id,
           admin_author_id: admin_author_id,
           started_at: started_at
         }}
    end
  end

  @spec stop(Plug.Conn.t(), Author.t() | nil) :: {:ok, Plug.Conn.t(), map() | nil}
  def stop(conn, _admin_author \\ nil) do
    masquerade = from_session(get_session(conn))

    case masquerade do
      nil ->
        {:ok, clear(conn), nil}

      %{subject_id: subject_id, subject_type: :user} = payload ->
        target_user_token = get_session(conn, :masquerade_target_user_token)

        if is_binary(target_user_token) do
          Accounts.delete_user_session_token(target_user_token)
        end

        conn =
          conn
          |> restore_original_author_session()
          |> restore_original_user_session()
          |> clear()

        {:ok, conn,
         %{
           subject_type: :user,
           subject_id: subject_id,
           subject_name: payload.subject_name,
           subject_email: payload.subject_email,
           admin_author_id: payload.admin_author_id,
           started_at: payload.started_at,
           duration_seconds: duration_seconds(payload.started_at)
         }}
    end
  end

  @spec clear(Plug.Conn.t()) :: Plug.Conn.t()
  def clear(conn) do
    Enum.reduce(@session_keys, conn, fn key, conn ->
      delete_session(conn, key)
    end)
  end

  @spec active?(map() | nil) :: boolean
  def active?(session_or_assigns) do
    match?(%{active: true}, from_source(session_or_assigns))
  end

  @spec subject(map() | nil) :: masquerade_subject | nil
  def subject(session_or_assigns) do
    case from_source(session_or_assigns) do
      %{subject_type: :user, subject_id: subject_id} -> %{type: :user, id: subject_id}
      _ -> nil
    end
  end

  @spec from_session(map()) :: masquerade_payload | nil
  def from_session(session) when is_map(session) do
    active = read_key(session, "masquerade_active")
    subject_type = read_key(session, "masquerade_subject_type")
    subject_id = read_key(session, "masquerade_subject_id")
    admin_author_id = read_key(session, "masquerade_admin_author_id")

    if truthy?(active) and subject_type == "user" and is_integer(subject_id) and
         is_integer(admin_author_id) do
      %{
        active: true,
        subject_type: :user,
        subject_id: subject_id,
        subject_name: read_key(session, "masquerade_subject_name"),
        subject_email: read_key(session, "masquerade_subject_email"),
        admin_author_id: admin_author_id,
        started_at: read_key(session, "masquerade_started_at")
      }
    else
      nil
    end
  end

  def from_session(_), do: nil

  defp from_source(%{masquerade: masquerade}) when is_map(masquerade), do: masquerade
  defp from_source(%{"masquerade" => masquerade}) when is_map(masquerade), do: masquerade
  defp from_source(map) when is_map(map), do: from_session(map)
  defp from_source(_), do: nil

  defp restore_original_user_session(conn) do
    conn =
      case get_session(conn, :masquerade_original_user_token) do
        token when is_binary(token) -> put_session(conn, :user_token, token)
        _ -> delete_session(conn, :user_token)
      end

    case get_session(conn, :masquerade_original_current_user_id) do
      user_id when is_integer(user_id) -> put_session(conn, :current_user_id, user_id)
      _ -> delete_session(conn, :current_user_id)
    end
  end

  defp restore_original_author_session(conn) do
    conn =
      case get_session(conn, :masquerade_original_author_token) do
        token when is_binary(token) -> put_session(conn, :author_token, token)
        _ -> delete_session(conn, :author_token)
      end

    conn =
      case get_session(conn, :masquerade_original_current_author_id) do
        author_id when is_integer(author_id) -> put_session(conn, :current_author_id, author_id)
        _ -> delete_session(conn, :current_author_id)
      end

    case get_session(conn, :masquerade_original_author_live_socket_id) do
      socket_id when is_binary(socket_id) -> put_session(conn, :author_live_socket_id, socket_id)
      _ -> delete_session(conn, :author_live_socket_id)
    end
  end

  defp duration_seconds(nil), do: nil

  defp duration_seconds(started_at) when is_binary(started_at) do
    with {:ok, started_at, _offset} <- DateTime.from_iso8601(started_at) do
      DateTime.diff(DateTime.utc_now(), started_at, :second)
    else
      _ -> nil
    end
  end

  defp truthy?(true), do: true
  defp truthy?("true"), do: true
  defp truthy?(1), do: true
  defp truthy?(_), do: false

  defp read_key(map, key) do
    Map.get(map, key) || Map.get(map, Map.fetch!(@string_to_atom_keys, key))
  end
end
