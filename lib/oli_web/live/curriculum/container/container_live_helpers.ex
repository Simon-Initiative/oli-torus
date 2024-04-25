defmodule OliWeb.Curriculum.Container.ContainerLiveHelpers do
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
    case revision_params do
      %{"explanation_strategy" => %{"type" => "none"}} ->
        Map.put(revision_params, "explanation_strategy", nil)

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
end
