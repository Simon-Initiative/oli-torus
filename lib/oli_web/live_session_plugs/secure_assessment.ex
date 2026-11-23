defmodule OliWeb.LiveSessionPlugs.SecureAssessment do
  @moduledoc """
  Confines issued assessment credentials at mount across LiveViews. Delivery views
  also check current page policy and learner authentication on connected callbacks.
  """
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
  def on_mount(_, _, _, %{assigns: %{secure_boundary_installed: true}} = socket),
    do: {:cont, socket}

  def on_mount(realm, params, session, socket) when realm in [:default, :author] do
    route_params =
      case socket.view do
        OliWeb.Dialogue.WindowLive -> Map.take(session, ["section_slug", "resource_id"])
        _ -> params
      end

    case session do
      %{"secure_session_id" => id} when not is_nil(id) ->
        case Accounts.get_user_session_by_id(id) do
          {:ok, context} -> mount(socket, route_params, context)
          {:error, _} -> deny(socket)
        end

      %{"user_token" => token} when not is_nil(token) ->
        case Accounts.get_user_session(token) do
          {:ok, context} ->
            mount(socket, route_params, context)

          {:error, :unauthenticated} ->
            # A token can expire between the HTTP render and the socket mount.
            # Return through HTTP to discard the stale identity before mounting.
            login = if realm == :author, do: "/authors/log_in", else: "/users/log_in"
            {:halt, Phoenix.LiveView.redirect(socket, to: login)}
        end

      _ ->
        mount(socket, route_params, nil)
    end
  end

  defp mount(socket, params, context) do
    socket =
      socket
      |> assign(:user_session, context)
      |> assign(:secure_route_params, params)
      |> assign(:secure_boundary_installed, true)

    case check_target(context, socket.view, params) do
      :ok when socket.view not in @views ->
        {:cont, socket}

      :ok ->
        socket =
          socket
          |> Phoenix.LiveView.attach_hook(:secure_assessment_event, :handle_event, &event/3)
          |> Phoenix.LiveView.attach_hook(:secure_assessment_info, :handle_info, &info/2)
          |> Phoenix.LiveView.attach_hook(:secure_assessment_async, :handle_async, &async/3)

        case params == :not_mounted_at_router or socket.view == OliWeb.Dialogue.WindowLive do
          true ->
            {:cont, socket}

          false ->
            {:cont,
             Phoenix.LiveView.attach_hook(
               socket,
               :secure_assessment_params,
               :handle_params,
               &params/3
             )}
        end

      {:error, _} ->
        deny(socket)
    end
  end

  defp check_target(session, view, params) when view in @views,
    do: Boundary.check_if_supported(session, view, :show, params)

  defp check_target(%{scope: %{}}, _view, _params), do: {:error, :secure_resource_mismatch}
  defp check_target(_session, _view, _params), do: :ok

  @doc "Checks current target policy and verifies the mounted learner identity before delivery callbacks."
  def authorize(socket, params) do
    session = socket.assigns[:user_session]

    with :ok <- check_target(session, socket.view, params) do
      case session do
        %{token_id: id, scope: scope} when socket.view in @views ->
          case Accounts.get_user_session_by_id(id) do
            {:ok, %{scope: ^scope}} -> :ok
            {:error, :unauthenticated} when is_nil(scope) -> {:error, :learner_login_required}
            _ -> {:error, :unauthenticated}
          end

        _ ->
          :ok
      end
    end
  end

  defp event(name, _payload, socket) do
    scoped? = match?(%{scope: %{}}, socket.assigns[:user_session])

    case not scoped? or name in @events do
      true -> continue_if_authorized(socket)
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

    case permitted? do
      true -> continue_if_authorized(socket)
      false -> deny(socket)
    end
  end

  defp authorize_question_message(socket, guid) do
    with %{token_id: id} <- socket.assigns[:user_session],
         {:ok, session} <- Accounts.get_user_session_by_id(id) do
      Boundary.check(
        session,
        OliWeb.Api.AttemptController,
        :save_activity,
        Map.put(socket.assigns.secure_route_params, "activity_attempt_guid", guid)
      )
    else
      _ -> {:error, :unauthenticated}
    end
  end

  defp params(params, _uri, socket) do
    socket |> assign(:secure_route_params, params) |> continue_if_authorized()
  end

  defp async(_name, _result, socket), do: continue_if_authorized(socket)

  defp continue_if_authorized(socket) do
    case authorize(socket, socket.assigns.secure_route_params) do
      :ok ->
        {:cont, socket}

      {:error, :learner_login_required} ->
        {:halt, Phoenix.LiveView.redirect(socket, to: "/users/log_in")}

      _ ->
        deny(socket)
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
