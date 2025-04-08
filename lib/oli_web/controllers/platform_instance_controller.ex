defmodule OliWeb.PlatformInstanceController do
  use OliWeb, :controller

  alias Oli.Repo
  alias Oli.Lti.{PlatformInstances, PlatformExternalTools}
  alias Lti_1p3.DataProviders.EctoProvider.PlatformInstance
  alias Oli.Activities
  alias Oli.Utils.Slug
  alias Lti_1p3.Platform.LoginHint
  alias Lti_1p3.Platform.LoginHints

  def index(conn, _params) do
    lti_1p3_platform_instances = PlatformInstances.list_lti_1p3_platform_instances()
    render(conn, "index.html", lti_1p3_platform_instances: lti_1p3_platform_instances)
  end

  def new(conn, _params) do
    changeset = PlatformInstances.change_platform_instance(%PlatformInstance{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{
        "platform_instance" => platform_instance_params
      }) do
    Repo.transaction(fn ->
      with {:ok, platform_instance} <-
             PlatformInstances.create_platform_instance(platform_instance_params),
           {:ok, activity_registration} <-
             Activities.register_lti_external_tool_activity(
               platform_instance_params["name"],
               platform_instance_params["name"],
               platform_instance_params["description"]
             ),
           {:ok, deployment} <-
             PlatformExternalTools.create_lti_external_tool_activity_deployment(%{
               platform_instance_id: platform_instance.id,
               activity_registration_id: activity_registration.id
             })
             |> dbg do
        {platform_instance, deployment}
      else
        error -> Repo.rollback(error)
      end
    end)
    |> case do
      {:ok, {platform_instance, _deployment}} ->
        conn
        |> put_flash(:info, "Platform instance created successfully.")
        |> redirect(to: Routes.platform_instance_path(conn, :show, platform_instance))

      {:error, {:error, %Ecto.Changeset{} = changeset}} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    platform_instance = PlatformInstances.get_platform_instance!(id)

    author = conn.assigns[:current_author]
    {:ok, %LoginHint{value: login_hint}} = LoginHints.create_login_hint(author.id, "author")

    launch_params = %{
      iss: Oli.Utils.get_base_url(),
      login_hint: login_hint,
      client_id: platform_instance.client_id,
      target_link_uri: platform_instance.target_link_uri,
      oidc_login_url: platform_instance.login_url
    }

    deployment =
      PlatformExternalTools.get_lti_external_tool_activity_deployment_by(
        platform_instance_id: platform_instance.id
      )

    render(conn, "show.html",
      platform_instance: platform_instance,
      deployment: deployment,
      launch_params: launch_params
    )
  end

  def edit(conn, %{"id" => id}) do
    platform_instance = PlatformInstances.get_platform_instance!(id)
    changeset = PlatformInstances.change_platform_instance(platform_instance)
    render(conn, "edit.html", platform_instance: platform_instance, changeset: changeset)
  end

  def update(conn, %{"id" => id, "platform_instance" => platform_instance_params}) do
    platform_instance = PlatformInstances.get_platform_instance!(id)

    case PlatformInstances.update_platform_instance(platform_instance, platform_instance_params) do
      {:ok, platform_instance} ->
        conn
        |> put_flash(:info, "Platform instance updated successfully.")
        |> redirect(to: Routes.platform_instance_path(conn, :show, platform_instance))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", platform_instance: platform_instance, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    platform_instance = PlatformInstances.get_platform_instance!(id)

    # This delete will cascade to any associated deployment
    {:ok, _platform_instance} = PlatformInstances.delete_platform_instance(platform_instance)

    conn
    |> put_flash(:info, "Platform instance deleted successfully.")
    |> redirect(to: Routes.platform_instance_path(conn, :index))
  end
end
