defmodule OliWeb.LiveSessionPlugs.SecureAssessment do
  @moduledoc "Current-credential authorization before LiveView mount and every connected callback."
  import Phoenix.Component, only: [assign: 3]
  alias Oli.Accounts
  alias OliWeb.Plugs.SecureAssessment, as: Boundary

  @views [
    OliWeb.Delivery.Student.PrologueLive,
    OliWeb.Delivery.Student.LessonLive,
    OliWeb.Delivery.Student.ReviewLive,
    OliWeb.Dialogue.WindowLive
  ]
  @events ["begin_attempt", "finalize_attempt", "select_question", "survey_scripts_loaded"]

  @doc false
  def on_mount(:default, _, _, %{assigns: %{secure_boundary_installed: true}} = socket),
    do: {:cont, socket}

  def on_mount(:default, params, session, socket) do
    route_params =
      case socket.view do
        OliWeb.Dialogue.WindowLive -> Map.take(session, ["section_slug", "resource_id"])
        _ -> params
      end

    result =
      case session["secure_session_id"] do
        nil -> Accounts.get_user_session(session["user_token"])
        id -> Accounts.get_user_session_by_id(id)
      end

    context =
      case result do
        {:ok, context} -> context
        _ -> nil
      end

    socket =
      socket
      |> assign(:user_session, context)
      |> assign(:secure_route_params, route_params)
      |> assign(:secure_boundary_installed, true)

    authorized =
      case {context, session["user_token"] || session["secure_session_id"]} do
        {nil, credential} when not is_nil(credential) -> {:error, :unauthenticated}
        _ -> authorize(socket, route_params)
      end

    case authorized do
      :ok ->
        socket =
          socket
          |> Phoenix.LiveView.attach_hook(:secure_assessment_event, :handle_event, &event/3)
          |> Phoenix.LiveView.attach_hook(:secure_assessment_info, :handle_info, &info/2)
          |> Phoenix.LiveView.attach_hook(:secure_assessment_async, :handle_async, &async/3)

        socket =
          case params do
            :not_mounted_at_router ->
              socket

            _ ->
              Phoenix.LiveView.attach_hook(
                socket,
                :secure_assessment_params,
                :handle_params,
                &params/3
              )
          end

        {:cont, socket}

      _ ->
        deny(socket)
    end
  end

  @doc "Revalidates a server-held session reference and current target policy, including components."
  def authorize(socket, params) do
    case socket.assigns[:user_session] do
      nil ->
        :ok

      %{scope: nil} when socket.view not in @views ->
        :ok

      %{token_id: id} ->
        with {:ok, session} <- Accounts.get_user_session_by_id(id) do
          case socket.view in @views do
            true -> Boundary.check(session, socket.view, :show, params)
            false when is_nil(session.scope) -> :ok
            false -> {:error, :secure_resource_mismatch}
          end
        end
    end
  end

  defp event(name, _payload, socket) do
    scoped? = match?(%{scope: %{}}, socket.assigns[:user_session])

    case (not scoped? or name in @events) and
           authorize(socket, socket.assigns.secure_route_params) == :ok do
      true -> {:cont, socket}
      false -> deny(socket)
    end
  end

  defp info(message, socket) do
    scoped? = match?(%{scope: %{}}, socket.assigns[:user_session])

    permitted? =
      case message do
        :gc ->
          true

        {:disable_question_inputs, _} ->
          true

        {:question_answered, %{activity_attempt_guid: guid}} ->
          not scoped? or authorize_question_message(socket, guid) == :ok

        _ ->
          not scoped?
      end

    case permitted? and authorize(socket, socket.assigns.secure_route_params) == :ok do
      true -> {:cont, socket}
      false -> deny(socket)
    end
  end

  defp authorize_question_message(socket, guid) do
    with %{token_id: id} <- socket.assigns[:user_session],
         {:ok, session} <- Accounts.get_user_session_by_id(id) do
      Boundary.check(
        session,
        OliWeb.Api.AttemptController,
        :get_activity_attempt,
        Map.put(socket.assigns.secure_route_params, "activity_attempt_guid", guid)
      )
    else
      _ -> {:error, :unauthenticated}
    end
  end

  defp params(params, _uri, socket) do
    case authorize(socket, params) do
      :ok -> {:cont, assign(socket, :secure_route_params, params)}
      _ -> deny(socket)
    end
  end

  defp async(_name, _result, socket) do
    case authorize(socket, socket.assigns.secure_route_params) do
      :ok -> {:cont, socket}
      _ -> deny(socket)
    end
  end

  defp deny(socket) do
    :telemetry.execute([:oli, :secure_assessment, :denied], %{count: 1}, %{
      reason: :secure_resource_mismatch,
      transport: :live_view
    })

    {:halt, Phoenix.LiveView.redirect(socket, to: "/secure-assessment/restricted")}
  end
end
