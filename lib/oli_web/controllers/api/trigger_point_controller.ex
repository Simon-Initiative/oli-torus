defmodule OliWeb.Api.TriggerPointController do
  @moduledoc """
  Endpoints to invoke AI trigger points from the client.
  """

  import OliWeb.Api.Helpers

  use OliWeb, :controller

  def invoke(conn, %{"section_slug" => section_slug}) do

    current_user = Map.get(conn.assigns, :current_user)
    section = Sections.get_section_by_slug(section_slug)

    case Oli.Conversation.Triggers.verify_access(section_slug, current_user.id) do
      {:ok, section} ->

        trigger = conn.body_params["trigger"]

        case TriggerPoint.invoke(section, current_user, trigger) do
          {:ok, result} ->
            json(conn, %{"type" => "submitted"})

          {:error, reason} ->
            json(conn, %{"type" => "failured", "reason" => reason})
        end

      {:error, :no_access} ->
        json(conn, %{"type" => "failure", "reason" => "User does not have permission to invoke trigger point."})
    end

  end

end
