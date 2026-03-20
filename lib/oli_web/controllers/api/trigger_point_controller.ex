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
        with {:ok, trigger} <-
               Oli.Conversation.Triggers.resolve_client_trigger(
                 section_slug,
                 section.id,
                 current_user.id,
                 conn.body_params["trigger"] || %{}
               ),
             :ok <- Oli.Conversation.Triggers.invoke(section.id, current_user.id, trigger) do
          json(conn, %{"type" => "submitted"})
        else
          {:error, :invalid_trigger} ->
            json(conn, %{"type" => "failure", "reason" => "Invalid trigger point"})

          e ->
            Logger.error(
              "Unable to invoke trigger point for section: #{section_slug} and user: #{current_user.id}, error: #{inspect(e)}"
            )

            json(conn, %{"type" => "failure", "reason" => "Unable to invoke trigger point"})
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
