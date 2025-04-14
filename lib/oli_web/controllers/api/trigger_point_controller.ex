defmodule OliWeb.Api.TriggerPointController do
  @moduledoc """
  Endpoints to invoke AI activation points from the client.
  """

  use OliWeb, :controller
  require Logger

  def invoke(conn, %{"section_slug" => section_slug}) do
    current_user = Map.get(conn.assigns, :current_user)

    Logger.info(
      "Client-side trigger point invocation for section: #{section_slug} and user: #{current_user.id}"
    )

    case Oli.Conversation.Triggers.verify_access(section_slug, current_user.id) do
      {:ok, section} ->
        trigger =
          conn.body_params["trigger"]
          |> Oli.Conversation.Trigger.parse(section.id, current_user.id)

        case Oli.Conversation.Triggers.invoke(section.id, current_user.id, trigger) do
          :ok ->
            json(conn, %{"type" => "submitted"})

          e ->
            Logger.error(
              "Unable to invoke trigger point for section: #{section_slug} and user: #{current_user.id}, error: #{inspect(e)}"
            )

            json(conn, %{"type" => "failured", "reason" => "Unable to invoke trigger point"})
        end

      {:error, :no_access} ->
        Logger.info(
          "User does not have permission to invoke trigger for section: #{section_slug} and user: #{current_user.id}"
        )

        json(conn, %{
          "type" => "failure",
          "reason" => "User does not have permission to invoke trigger point"
        })
    end
  end
end
