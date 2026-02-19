defmodule OliWeb.Plugs.FetchMasquerade do
  import Plug.Conn

  require Logger

  alias Oli.Accounts
  alias OliWeb.Accounts.Masquerade
  alias Oli.Auditing
  alias Oli.Features

  @feature_label "admin-act-as-user"

  def init(opts), do: opts

  def call(conn, _opts) do
    masquerade = Masquerade.from_session(get_session(conn))

    cond do
      is_nil(masquerade) ->
        assign(conn, :masquerade, nil)

      Features.enabled?(@feature_label) ->
        assign(conn, :masquerade, masquerade)

      true ->
        admin = resolve_admin_actor(conn, masquerade)

        {:ok, conn, stop_details} = Masquerade.stop(conn, admin)

        if stop_details do
          maybe_capture_audit(admin, :masquerade_stopped, %{
            "subject_type" => "user",
            "subject_id" => stop_details.subject_id,
            "subject_name" => stop_details.subject_name,
            "subject_email" => stop_details.subject_email,
            "admin_author_id" => stop_details.admin_author_id,
            "started_at" => stop_details.started_at,
            "stopped_at" =>
              DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601(),
            "duration_seconds" => stop_details.duration_seconds,
            "reason" => "flag_disabled"
          })
        end

        assign(conn, :masquerade, nil)
    end
  end

  defp resolve_admin_actor(conn, masquerade) do
    conn.assigns[:current_author] || Accounts.get_author(masquerade.admin_author_id)
  end

  defp maybe_capture_audit(nil, _event_type, _details), do: :ok

  defp maybe_capture_audit(actor, event_type, details) do
    case Auditing.capture(actor, event_type, nil, details) do
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
