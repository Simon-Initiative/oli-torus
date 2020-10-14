defmodule OliWeb.Breadcrumb.BreadcrumbProvider do
  alias Oli.Resources
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Resources.Numbering
  alias OliWeb.Router.Helpers, as: Routes

  defstruct full_title: "",
  short_title: "",
  link: nil,
  action_descriptions: []

  def new(%{ full_title: full_title, short_title: short_title } = params) do
    %__MODULE__{
      full_title: full_title,
      short_title: short_title,
    }
    |> put(:link, params)
    |> put(:action_descriptions, params)
  end
  def new(%{ full_title: full_title } = params) do
    new(Map.put(params, :short_title, full_title))
  end

  defp put(map, key, params) do
    if Map.get(params, key)
    do Map.put(map, key, Map.get(params, key))
    else map
    end
  end

  def build_trail_to(project_slug, revision_slug) do
    # rev id to numbering
    numberings = Numbering.number_full_tree(project_slug)
    {:ok, [root | path]} = AuthoringResolver.path_to(project_slug, Resources.get_resource_from_slug(revision_slug).id)

    IO.inspect(path)
    Enum.map(path, fn revision_id ->
      numbering = Map.get(numberings, revision_id)
      %__MODULE__{
      full_title: Numbering.prefix(numbering) <> ": " <> numbering.container.title,
      link: Routes.live_path(OliWeb.Endpoint, OliWeb.Curriculum.Container, project_slug, numbering.container.slug)
    } end)
  end

  # Add ability to make a list of providers as a BreadcrumbTrail (maybe make new module)
  # Each controller using the breadcrumb trail will make a list of providers and send the BreadCrumbTrail as an assign to the _project_header
end
