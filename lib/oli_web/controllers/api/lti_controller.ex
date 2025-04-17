defmodule OliWeb.Api.LtiController do
  use OliWeb, :controller

  alias Lti_1p3.Platform.LoginHint
  alias Lti_1p3.Platform.LoginHints
  alias Oli.Publishing.{DeliveryResolver, AuthoringResolver}
  alias Oli.Lti.PlatformExternalTools
  alias Oli.Lti.PlatformExternalTools.LtiExternalToolActivityDeployment

  action_fallback OliWeb.FallbackController

  def launch_details(conn, %{"section_slug" => section_slug, "activity_id" => activity_id}) do
    with %Oli.Resources.Revision{activity_type_id: activity_type_id} <-
           DeliveryResolver.from_resource_id(section_slug, activity_id),
         %LtiExternalToolActivityDeployment{platform_instance: platform_instance} =
           PlatformExternalTools.get_lti_external_tool_activity_deployment_by(
             activity_registration_id: activity_type_id
           ) do
      user = conn.assigns[:current_user]

      {:ok, %LoginHint{value: login_hint}} =
        LoginHints.create_login_hint(user.id, %{
          "section" => section_slug,
          "resource_id" => activity_id
        })

      json(conn, %{
        name: platform_instance.name,
        launch_params: %{
          iss: Oli.Utils.get_base_url(),
          login_hint: login_hint,
          client_id: platform_instance.client_id,
          target_link_uri: platform_instance.target_link_uri,
          login_url: platform_instance.login_url
        }
      })
    else
      _ ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Activity not found"})
        |> halt()
    end
  end

  def launch_details(conn, %{"project_slug" => project_slug, "activity_id" => activity_id}) do
    with %Oli.Resources.Revision{activity_type_id: activity_type_id} <-
           AuthoringResolver.from_resource_id(project_slug, activity_id),
         %LtiExternalToolActivityDeployment{platform_instance: platform_instance} =
           PlatformExternalTools.get_lti_external_tool_activity_deployment_by(
             activity_registration_id: activity_type_id
           ) do
      author = conn.assigns[:current_author]

      {:ok, %LoginHint{value: login_hint}} =
        LoginHints.create_login_hint(author.id, %{
          "project" => project_slug,
          "resource_id" => activity_id
        })

      json(conn, %{
        name: platform_instance.name,
        launch_params: %{
          iss: Oli.Utils.get_base_url(),
          login_hint: login_hint,
          client_id: platform_instance.client_id,
          target_link_uri: platform_instance.target_link_uri,
          login_url: platform_instance.login_url
        }
      })
    else
      _ ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Activity not found"})
        |> halt()
    end
  end
end
