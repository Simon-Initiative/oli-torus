defmodule OliWeb.MasqueradeController do
  use OliWeb, :controller

  require Logger

  alias Oli.Accounts
  alias OliWeb.Accounts.Masquerade
  alias Oli.Auditing
  alias Oli.Features
  alias OliWeb.Common.Links

  @feature_label "admin-act-as-user"

  def confirm(conn, %{"user_id" => user_id}) do
    with :ok <- ensure_feature_enabled(),
         {:ok, admin} <- ensure_system_admin(conn),
         {:ok, target_user} <- fetch_target_user(user_id),
         :ok <- ensure_inactive(conn) do
      render(conn, "confirm.html", admin: admin, target_user: target_user)
    else
      {:error, :not_found} ->
        conn
        |> put_flash(:error, "User not found")
        |> redirect(to: ~p"/admin/users")

      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: ~p"/admin/users/#{user_id}")
    end
  end

  def start(conn, %{"user_id" => user_id}) do
    with :ok <- ensure_feature_enabled(),
         {:ok, admin} <- ensure_system_admin(conn),
         {:ok, target_user} <- fetch_target_user(user_id),
         {:ok, conn, start_details} <- Masquerade.start(conn, admin, target_user) do
      maybe_capture_audit(admin, :masquerade_started, target_user, %{
        "subject_type" => "user",
        "subject_id" => start_details.subject_id,
        "subject_name" => target_user.name,
        "subject_email" => target_user.email,
        "admin_author_id" => start_details.admin_author_id,
        "started_at" => start_details.started_at
      })

      conn
      |> put_flash(:info, "You are now acting as #{target_user.name}.")
      |> redirect(to: Links.my_courses_path(target_user))
    else
      {:error, :already_active} ->
        conn
        |> put_flash(:error, "Stop the active act-as-user session before starting another.")
        |> redirect(to: ~p"/admin/users/#{user_id}")

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "User not found")
        |> redirect(to: ~p"/admin/users")

      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: ~p"/admin/users/#{user_id}")
    end
  end

  def stop(conn, _params) do
    with {:ok, admin} <- resolve_masquerade_admin(conn),
         {:ok, conn, stop_details} <- stop_masquerade(conn, admin) do
      redirect_to =
        case stop_details do
          %{subject_id: subject_id} when is_integer(subject_id) -> ~p"/admin/users/#{subject_id}"
          _ -> ~p"/admin/users"
        end

      conn
      |> put_flash(:info, "Stopped acting as user.")
      |> redirect(to: redirect_to)
    else
      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: ~p"/admin/users")
    end
  end

  defp stop_masquerade(conn, admin) do
    case Masquerade.stop(conn, admin) do
      {:ok, conn, nil} ->
        {:ok, conn, nil}

      {:ok, conn, stop_details} ->
        maybe_capture_audit(admin, :masquerade_stopped, nil, %{
          "subject_type" => "user",
          "subject_id" => stop_details.subject_id,
          "subject_name" => stop_details.subject_name,
          "subject_email" => stop_details.subject_email,
          "admin_author_id" => stop_details.admin_author_id,
          "started_at" => stop_details.started_at,
          "stopped_at" =>
            DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601(),
          "duration_seconds" => stop_details.duration_seconds
        })

        {:ok, conn, stop_details}
    end
  end

  defp resolve_masquerade_admin(conn) do
    case Masquerade.from_session(get_session(conn)) do
      %{admin_author_id: admin_author_id} ->
        case Accounts.get_author(admin_author_id) do
          nil -> {:error, "Unable to restore the original admin session."}
          admin -> {:ok, admin}
        end

      _ ->
        {:error, "No active act-as-user session."}
    end
  end

  defp ensure_feature_enabled do
    if Features.enabled?(@feature_label), do: :ok, else: {:error, "Feature is disabled."}
  end

  defp ensure_system_admin(%{assigns: %{current_author: author}}) do
    if Accounts.has_admin_role?(author, :system_admin) do
      {:ok, author}
    else
      {:error, "You must be a system admin to perform this action."}
    end
  end

  defp fetch_target_user(user_id) do
    case Accounts.get_user(user_id, preload: [:platform_roles]) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  defp ensure_inactive(conn) do
    if Masquerade.active?(get_session(conn)) do
      {:error, "A masquerade session is already active."}
    else
      :ok
    end
  end

  defp maybe_capture_audit(actor, event_type, resource, details) do
    case Auditing.capture(actor, event_type, resource, details) do
      {:ok, _event} ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "Failed to capture masquerade audit event #{inspect(event_type)}: #{inspect(reason)}"
        )

        :ok
    end
  end
end
