defmodule OliWeb.Curriculum.Container.ContainerLiveHelpers do
  import Phoenix.Component, only: [assign: 2, assign: 3]
  import Phoenix.LiveView, only: [push_navigate: 2, put_flash: 3]
  alias Oli.Publishing.AuthoringResolver
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Resources
  import OliWeb.Curriculum.Utils
  alias Oli.Delivery.Hierarchy

  ## assign helpers
  def build_option_modal_assigns(redirect_url, children, slug) do
    revision = Enum.find(children, fn r -> r.slug == slug end)

    form = revision |> Resources.change_revision() |> Phoenix.Component.to_form()

    %{
      id: "options_#{slug}",
      redirect_url: redirect_url,
      revision: revision,
      title: "#{resource_type_label(revision) |> String.capitalize()} Options",
      form: form
    }
  end

  def build_redirect_url(socket, project_slug, container_slug) do
    Routes.container_path(socket, :index, project_slug, container_slug)
  end

  def decode_revision_params(revision_params) do
    revision_params
    |> maybe_decode_intro_content
  end

  defp maybe_decode_intro_content(revision_params) do
    case revision_params do
      %{"intro_content" => intro_content} when intro_content in ["", nil] ->
        Map.put(
          revision_params,
          "intro_content",
          %{}
        )

      %{"intro_content" => intro_content} ->
        Map.put(
          revision_params,
          "intro_content",
          Jason.decode!(intro_content)
        )

      _ ->
        revision_params
    end
  end

  def build_modal_assigns(container_slug, project_slug, slug) do
    hierarchy = AuthoringResolver.full_hierarchy(project_slug)
    node = Hierarchy.find_in_hierarchy(hierarchy, fn n -> n.revision.slug == slug end)
    active = Hierarchy.find_in_hierarchy(hierarchy, fn n -> n.revision.slug == container_slug end)

    %{
      id: "move_#{slug}",
      node: node,
      hierarchy: hierarchy,
      from_container: active,
      active: active
    }
  end

  @doc """
  Shared handler for save-options event in curriculum, container, and pages LiveViews
  """
  def handle_save_options(socket, revision_params) do
    %{
      options_modal_assigns: %{redirect_url: redirect_url, revision: revision},
      project: project,
      author: author
    } =
      socket.assigns

    revision_params =
      revision_params
      |> Map.put("author_id", author.id)
      |> decode_revision_params()

    case Oli.Authoring.Editing.ContainerEditor.edit_page(project, revision.slug, revision_params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "#{OliWeb.Curriculum.Utils.resource_type_label(revision) |> String.capitalize()} options saved"
         )
         |> push_navigate(to: redirect_url)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @doc """
  Shared handler for validate-options event in curriculum, container, and pages LiveViews
  """
  def handle_validate_options(socket, revision_params) do
    %{options_modal_assigns: %{revision: revision} = modal_assigns} = socket.assigns

    revision_params = decode_revision_params(revision_params)

    changeset =
      revision
      |> Oli.Resources.change_revision(revision_params)
      |> Map.put(:action, :validate)
      |> Phoenix.Component.to_form()

    {:noreply, assign(socket, options_modal_assigns: %{modal_assigns | form: changeset})}
  end
end
