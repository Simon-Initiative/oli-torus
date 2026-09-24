defmodule OliWeb.Plugs.SecureAssessment do
  @moduledoc """
  Early browser boundary. Runs before delivery context, redirects and controller
  work. Unclassified routes are denied for scoped credentials; service-only
  authentication does not use this browser policy.
  """
  import Plug.Conn

  alias Oli.Delivery.SecureAssessments, as: Policy
  alias Oli.Delivery.Sections.Section
  alias Oli.Repo

  @doc false
  def init(opts), do: opts

  @doc false
  def call(conn, _) do
    route = Phoenix.Router.route_info(OliWeb.Router, conn.method, conn.request_path, conn.host)

    {controller, action} =
      case route do
        %{phoenix_live_view: {view, action, _, _}} -> {view, action}
        %{plug: controller, plug_opts: action} -> {controller, action}
        _ -> {nil, nil}
      end

    case check(conn.assigns[:user_session], controller, action, conn.params) do
      :ok ->
        case classify(controller, action, conn.params) do
          value when value in [:authentication, :unmapped] -> conn
          _ -> put_resp_header(conn, "cache-control", "no-store")
        end

      {:error, reason} ->
        deny(conn, reason)
    end
  end

  @doc "Checks server-selected route actions without invoking their delivery side effects."
  def check(session, controller, action, params) do
    scope = session && session.scope
    user_id = session && session.user.id

    case classify(controller, action, params) do
      :authentication ->
        :ok

      :unmapped when is_nil(scope) ->
        :ok

      :unmapped ->
        {:error, :secure_resource_mismatch}

      _ when is_nil(session) ->
        :ok

      {:page, operation} ->
        with {:ok, target} <- Policy.resolve_page(params["section_slug"], params["revision_slug"]),
             {:ok, _} <- Policy.authorize(scope, user_id, operation, target) do
          :ok
        end

      :index ->
        with {:ok, index} <- parse_index(params["page_number"]),
             revision when not is_nil(revision) <-
               Oli.Delivery.Sections.get_revision_by_index(params["section_slug"], index),
             {:ok, target} <- Policy.resolve_page(params["section_slug"], revision.slug),
             {:ok, _} <- Policy.authorize(scope, user_id, :deliver, target) do
          :ok
        else
          _ -> {:error, :not_found}
        end

      {:models, ids} ->
        authorize_models(scope, params["section_slug"], ids)

      {:attempt_models, ids} ->
        case params["resource_attempt_guid"] do
          nil ->
            authorize_models(scope, params["section_slug"], ids)

          guid ->
            with {:ok, ids} <- parse_ids(ids),
                 {:ok, target, _} <- Policy.resolve_models(guid, ids),
                 {:ok, parents} <- parents(params) do
              Policy.authorize_batch(scope, user_id, :dependency_read, [target], parents)
            end
        end

      {:report, section_id, resource_id} ->
        with {:ok, [section_id]} <- parse_ids([section_id]),
             section when not is_nil(section) <- Repo.get(Section, section_id) do
          authorize_models(scope, section.slug, [resource_id])
        else
          _ -> {:error, :not_found}
        end

      {:blob, guid, operation} ->
        case Policy.resolve_attempts(:resource, [guid]) do
          {:ok, targets} -> Policy.authorize_batch(scope, user_id, operation, targets)
          _ when is_nil(scope) -> :ok
          _ -> {:error, :secure_resource_mismatch}
        end

      {:legacy, guid, operation} ->
        case {scope, Policy.resolve_attempts(:activity, [guid])} do
          {%{}, _} ->
            {:error, :secure_resource_mismatch}

          {nil, {:ok, targets}} ->
            Policy.authorize_batch(scope, user_id, operation, targets)

          {nil, {:error, :not_found}} ->
            # Preview capabilities are server-created, distinct from persisted attempts.
            # The controller still applies its existing actor/author ownership check.
            case Oli.Interop.CustomActivities.PreviewSessions.get(guid) do
              {:ok, _} -> :ok
              _ -> {:error, :not_found}
            end

          {nil, error} ->
            error
        end

      {:attempts, kind, guids, operation} ->
        with :ok <- projection_limit(params),
             {:ok, targets} <- Policy.resolve_attempts(kind, guids, mutation?(operation)),
             {:ok, parents} <- parents(params),
             :ok <- Policy.authorize_batch(scope, user_id, operation, targets, parents),
             :ok <- nested_parts(scope, user_id, operation, params, parents) do
          :ok
        end
    end
  end

  defp classify(OliWeb.LtiController, action, _) when action in [:login, :launch],
    do: :authentication

  defp classify(OliWeb.UserSessionController, action, _) when action in [:new, :create, :delete],
    do: :authentication

  defp classify(OliWeb.SecureAssessmentController, action, _)
       when action in [:restricted, :exit, :signed_out], do: :authentication

  # These callbacks authenticate service credentials independently of browser sessions.
  defp classify(OliWeb.LtiAgsController, _, _), do: :authentication

  defp classify(OliWeb.Api.ActivityController, :retrieve_delivery, p),
    do: {:attempt_models, [p["resource"]]}

  defp classify(OliWeb.Api.ActivityController, :bulk_retrieve_delivery, p),
    do: {:attempt_models, p["resourceIds"]}

  defp classify(OliWeb.Api.LtiController, :launch_details, %{
         "section_slug" => _,
         "activity_id" => id
       }),
       do: {:models, [id]}

  defp classify(OliWeb.Api.DirectedDiscussionController, _, p),
    do: {:models, [p["resource_id"]]}

  defp classify(OliWeb.Api.ActivityReportDataController, :fetch, p),
    do: {:report, p["section_id"], p["resource_id"]}

  defp classify(OliWeb.PageDeliveryController, :navigate_by_index, _), do: :index

  defp classify(OliWeb.Api.BlobStorageController, action, p)
       when action in [:read_key, :write_key],
       do:
         {:blob, p["key"], if(action == :read_key, do: :dependency_read, else: :dependency_write)}

  defp classify(OliWeb.LegacySuperactivityController, :context, p),
    do: {:legacy, p["attempt_guid"], :dependency_read}

  defp classify(OliWeb.LegacySuperactivityController, :process, p),
    do:
      {:legacy, p["activityContextGuid"],
       if(
         p["commandName"] in [
           "loadClientConfig",
           "beginSession",
           "loadContentFile",
           "loadFileRecord",
           "deleteFileRecord"
         ],
         do: :dependency_read,
         else: :dependency_write
       )}

  defp classify(OliWeb.Api.AttemptController, :bulk_retrieve, p),
    do: {:attempts, :activity, p["attemptGuids"], :review}

  defp classify(OliWeb.Api.AttemptController, action, p) do
    operation =
      case action do
        :get_activity_attempt -> :review
        action when action in [:new_activity, :new_part] -> :start
        action when action in [:submit_part, :submit_activity, :submit_evaluations] -> :submit
        _ -> :save
      end

    case p["part_attempt_guid"] do
      nil -> {:attempts, :activity, [p["activity_attempt_guid"]], operation}
      guid -> {:attempts, :part, [guid], operation}
    end
  end

  defp classify(OliWeb.Api.ResourceAttemptStateController, action, p),
    do:
      {:attempts, :resource, [p["resource_attempt_guid"]],
       if(action == :read, do: :dependency_read, else: :dependency_write)}

  defp classify(OliWeb.Api.PageLifecycleController, _, p),
    do: {:attempts, :resource, [p["attempt_guid"]], :submit}

  defp classify(OliWeb.PageDeliveryController, :review_attempt, p),
    do: {:attempts, :resource, [p["attempt_guid"]], :review}

  defp classify(OliWeb.PageDeliveryController, action, _)
       when action in [:page, :page_fullscreen, :start_attempt, :start_attempt_protected],
       do: {:page, :deliver}

  defp classify(OliWeb.Delivery.Student.ReviewLive, _, p),
    do: {:attempts, :resource, [p["attempt_guid"]], :review}

  defp classify(OliWeb.Dialogue.WindowLive, _, %{"section_slug" => _, "resource_id" => id})
       when not is_nil(id), do: {:models, [id]}

  defp classify(view, _, _)
       when view in [OliWeb.Delivery.Student.PrologueLive, OliWeb.Delivery.Student.LessonLive],
       do: {:page, :deliver}

  defp classify(_, _, _), do: :unmapped

  defp mutation?(operation), do: operation in [:start, :save, :submit, :dependency_write]

  defp parse_index(index) when is_integer(index) and index >= 0 and index <= 2_147_483_647,
    do: {:ok, index}

  defp parse_index(index) when is_binary(index) and byte_size(index) <= 10 do
    case Integer.parse(index) do
      {value, ""} -> parse_index(value)
      _ -> :error
    end
  end

  defp parse_index(_), do: :error

  defp authorize_models(scope, section_slug, ids) do
    with true <- is_list(ids) and length(ids) <= 100,
         {:ok, ids} <- parse_ids(ids) do
      cond do
        not is_nil(scope) -> {:error, :secure_resource_mismatch}
        Policy.protected_models?(section_slug, ids) -> {:error, :secure_launch_required}
        true -> :ok
      end
    else
      _ -> {:error, :invalid_batch}
    end
  end

  defp projection_limit(%{"keys" => keys}) when is_list(keys) and length(keys) <= 100,
    do: :ok

  defp projection_limit(%{"keys" => _}), do: {:error, :invalid_batch}
  defp projection_limit(_), do: :ok

  defp parse_ids(ids) when is_list(ids) and length(ids) <= 100 do
    Enum.reduce_while(ids, {:ok, []}, fn
      id, {:ok, acc} when is_integer(id) and id > 0 and id <= 9_223_372_036_854_775_807 ->
        {:cont, {:ok, [id | acc]}}

      id, {:ok, acc} when is_binary(id) and byte_size(id) <= 19 ->
        case Integer.parse(id) do
          {id, ""} when id > 0 and id <= 9_223_372_036_854_775_807 -> {:cont, {:ok, [id | acc]}}
          _ -> {:halt, {:error, :invalid_batch}}
        end

      _, _ ->
        {:halt, {:error, :invalid_batch}}
    end)
  end

  defp parse_ids(_), do: {:error, :invalid_batch}

  defp parents(params) do
    base =
      Map.take(params, ["activity_attempt_guid", "resource_attempt_guid"])
      |> Map.new(fn
        {"activity_attempt_guid", v} -> {:activity_attempt_guid, v}
        {"resource_attempt_guid", v} -> {:resource_attempt_guid, v}
      end)

    case {params["section_slug"], params["revision_slug"]} do
      {nil, nil} ->
        {:ok, base}

      {slug, nil} ->
        case Repo.get_by(Section, slug: slug) do
          nil -> {:error, :not_found}
          section -> {:ok, Map.put(base, :section_id, section.id)}
        end

      {slug, revision} ->
        with {:ok, target} <- Policy.resolve_page(slug, revision) do
          {:ok, Map.merge(base, Map.take(target, [:section_id, :resource_id]))}
        end
    end
  end

  defp nested_parts(scope, user_id, operation, params, parent) do
    Enum.reduce_while(["partInputs", "evaluations"], :ok, fn key, :ok ->
      case Map.fetch(params, key) do
        :error ->
          {:cont, :ok}

        {:ok, values} when is_list(values) and length(values) <= 1000 ->
          guids =
            Enum.map(values, fn
              %{"attemptGuid" => guid} -> guid
              _ -> nil
            end)

          result =
            with {:ok, targets} <- Policy.resolve_attempts(:part, guids, true) do
              Policy.authorize_batch(scope, user_id, operation, targets, parent)
            end

          case result do
            :ok -> {:cont, :ok}
            error -> {:halt, error}
          end

        _ ->
          {:halt, {:error, :invalid_batch}}
      end
    end)
  end

  @doc "Returns a non-cached, bounded denial without disclosing target or token identifiers."
  def deny(conn, reason) do
    :telemetry.execute([:oli, :secure_assessment, :denied], %{count: 1}, %{
      reason: reason,
      transport: :http
    })

    status =
      case reason do
        :not_found -> 404
        :unauthenticated -> 401
        :invalid_batch -> 400
        _ -> 403
      end

    conn = conn |> put_resp_header("cache-control", "no-store") |> put_status(status)

    case String.starts_with?(conn.request_path, "/api/") do
      true ->
        conn |> Phoenix.Controller.json(%{error: reason}) |> halt()

      false ->
        title = Gettext.gettext(OliWeb.Gettext, "Assessment access restricted")

        message =
          Gettext.gettext(
            OliWeb.Gettext,
            "Use your approved secure assessment launch to access this assessment. Other ordinary browser sessions are not restricted."
          )

        body = Phoenix.HTML.safe_to_string(Phoenix.HTML.html_escape(message))
        title = Phoenix.HTML.safe_to_string(Phoenix.HTML.html_escape(title))

        exit =
          case conn.assigns[:user_session] do
            %{scope: %{}} ->
              csrf =
                Phoenix.HTML.safe_to_string(
                  Phoenix.HTML.html_escape(Plug.CSRFProtection.get_csrf_token())
                )

              "<form action=\"/secure-assessment/exit\" method=\"post\" target=\"_top\"><input type=\"hidden\" name=\"_csrf_token\" value=\"#{csrf}\"><button type=\"submit\">Exit assessment</button></form>"

            _ ->
              ""
          end

        conn
        |> Phoenix.Controller.html(
          "<!doctype html><html lang=\"en\"><head><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>#{title}</title></head><body><main><h1>#{title}</h1><p>#{body}</p>#{exit}</main></body></html>"
        )
        |> halt()
    end
  end
end
