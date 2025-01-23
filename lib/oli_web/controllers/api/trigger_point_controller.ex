defmodule OliWeb.Api.TriggerPointController do
  @moduledoc """
  Endpoints to invoke AI trigger points from the client.
  """

  import OliWeb.Api.Helpers

  use OliWeb, :controller

  def invoke(conn, %{"section_slug" => section_slug}) do

    current_user = Map.get(conn.assigns, :current_user)

    case Oli.Conversation.Triggers.verify_access(section_slug, current_user.id) do
      {:ok, section} ->

        trigger = conn.body_params["trigger"] |> Oli.Conversation.Trigger.parse(section.id, current_user.id)

        case Oli.Conversation.Triggers.invoke(section, current_user, trigger) do
          :ok ->
            json(conn, %{"type" => "submitted"})

          _ ->
            json(conn, %{"type" => "failured", "reason" => "Unable to invoke trigger point."})
        end

      {:error, :no_access} ->
        json(conn, %{"type" => "failure", "reason" => "User does not have permission to invoke trigger point."})
    end

  end

end
