defmodule OliWeb.Common.Breadcrumb do
  alias Oli.Resources.Numbering
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Links

  @enforce_keys [:full_title]
  defstruct full_title: "",
            short_title: "",
            link: nil,
            slug: nil,
            action_descriptions: []

  @doc """
  Makes a new %Breadcrumb{}

  ## Parameters

    - attrs = %{
      full_title: required string,
      slug: required revision_slug (only for containers),
      short_title: optional string,
      link: optional Route,
      action_descriptions: optional list of dropdown menu actions
    }

  ## Examples

     iex> Breadcrumb.new(%{full_title: "Title"})
     %Breadcrumb{ full_title: "Title", short_title: "Title" }

  """
  def new(%{full_title: _full_title, short_title: _short_title} = params) do
    struct(__MODULE__, params)
  end
  def new(%{full_title: full_title} = params) do
    new(Map.put(params, :short_title, full_title))
  end

  @doc """
  Makes a breadcrumb trail (`%Breadcrumb{}[]`) from the curriculum through all the containers leading to the revision passed as an argument. A Breadcrumb is also created for the `revision_slug` at the end of the list.

  ## Parameters

    - project_slug
    - revision_slug

  ## Examples

     iex> Breadcrumb.trail_to(project_slug, revision_slug)
     [%Breadcrumb{ curriculum }, %Breadcrumb{ container_1 }, ..., %Breadcrumb{ revision_slug }]

  """
  def trail_to(project_slug, revision_slug) do
    [curriculum(project_slug) | trail_to_helper(project_slug, revision_slug)]
  end

  defp trail_to_helper(project_slug, revision_slug) do
    with numberings <- Numbering.number_full_tree(Oli.Publishing.AuthoringResolver, project_slug),
         {:ok, [_root | path]} = Numbering.path_from_root_to(
           Oli.Publishing.AuthoringResolver, project_slug, revision_slug) do
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
            slug: revision.slug,
            action_descriptions: [
              "Rename"
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

  @doc """
  Makes a %Breadcrumb{} to the curriculum route.

  ## Parameters

    - project_slug

  ## Examples

     iex> Breadcrumb.curriculum(project_slug, revision_slug)
     %Breadcrumb{ full_title: "Curriculum", link: curriculum_path }

  """
  def curriculum(project_slug) do
    new(%{
      full_title: "Curriculum",
      link:
        Routes.container_path(
          OliWeb.Endpoint,
          :index,
          project_slug
        )
    })
  end
end
