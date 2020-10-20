defmodule Oli.Utils.Breadcrumb do
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Resources.Numbering
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Links

  @enforce_keys [:full_title]
  defstruct full_title: "",
            short_title: "",
            link: nil,
            action_descriptions: []

  def new(%{full_title: _full_title, short_title: _short_title} = params) do
    struct(__MODULE__, params)
  end

  def new(%{full_title: full_title} = params) do
    new(Map.put(params, :short_title, full_title))
  end

  def trail_to(project_slug, revision_slug) do
    [curriculum(project_slug) | trail_to_helper(project_slug, revision_slug)]
  end

  defp trail_to_helper(project_slug, revision_slug) do
    with numberings <- Numbering.number_full_tree(project_slug),
         {:ok, [_root | path]} = Numbering.path_from_root_to(project_slug, revision_slug) do
      Enum.map(path, fn revision -> make_breadcrumb(project_slug, revision, numberings) end)
    end
  end

  defp make_breadcrumb(project_slug, revision, numberings) do
    with resource_type <- Oli.Resources.ResourceType.get_type_by_id(revision.resource_type_id),
         link <- Links.resource_path(revision, [], project_slug),
         numbering <- Map.get(numberings, revision.id) do
      case resource_type do
        "container" ->
          new(%{
            full_title: Numbering.prefix(numbering) <> ": " <> revision.title,
            short_title: Numbering.prefix(numbering),
            action_descriptions: [

            ],
            link: link
          })

        _ ->
          new(%{
            full_title: revision.title,
            link: link
          })
      end
    end
  end

  def curriculum(project_slug) do
    new(%{
      full_title: "Curriculum",
      link:
        Routes.container_path(
          OliWeb.Endpoint,
          :index,
          project_slug,
          AuthoringResolver.root_container(project_slug).slug
        )
    })
  end

  # Add ability to make a list of providers as a BreadcrumbTrail (maybe make new module)
  # Each controller using the breadcrumb trail will make a list of providers and send the BreadCrumbTrail as an assign to the _project_header
end
