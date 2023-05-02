defmodule Oli.Utils.Seeder.Section do
  import Oli.Utils.Seeder.Utils

  alias Oli.Repo
  alias Oli.Accounts.User
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Enrollment
  alias Oli.Utils.DataGenerators.NameGenerator
  alias Oli.Utils.Slug
  alias Oli.Publishing.DeliveryResolver

  @doc """
  Creates a section
  """
  def create_section(seeds, project, publication, institution, attrs \\ %{}, tags \\ []) do
    [project, publication, institution] = unpack(seeds, [project, publication, institution])

    customizations =
      case project.customizations do
        nil -> nil
        labels -> Map.from_struct(labels)
      end

    attrs =
      %{title: "Example Section", registration_open: true, context_id: UUID.uuid4()}
      |> Map.merge(attrs)
      |> Map.merge(%{
        institution_id:
          case institution do
            nil -> nil
            i -> i.id
          end,
        base_project_id: project.id,
        customizations: customizations
      })

    {:ok, section} =
      Sections.create_section(attrs)
      |> then(fn {:ok, section} -> section end)
      |> Sections.create_section_resources(publication)

    seeds
    |> tag(tags[:section_tag], section)
  end

  def create_section_from_product(
        seeds,
        product,
        instructor,
        institution,
        attrs \\ %{},
        tags \\ []
      ) do
    [product, instructor, institution] = unpack(seeds, [product, instructor, institution])

    attrs =
      %{
        type: :enrollable,
        title: "Example Section from Product",
        context_id: UUID.uuid4()
      }
      |> Map.merge(attrs)
      |> Map.merge(%{
        institution_id:
          case institution do
            nil -> nil
            i -> i.id
          end,
        base_project_id: product.base_project_id
      })

    {:ok, section} = Oli.Delivery.Sections.Blueprint.duplicate(product, attrs)

    seeds =
      case instructor do
        nil -> seeds
        instructor -> enroll_as_instructor(seeds, instructor, section)
      end

    seeds
    |> tag(tags[:section_tag], section)
  end

  def create_and_enroll_learner(seeds, section, user_attrs, tags \\ []) do
    user_tag = tags[:user_tag] || random_tag()

    seeds
    |> create_user(user_attrs, tags)
    |> enroll_as_learner(section, ref(user_tag))
  end

  def create_and_enroll_instructor(seeds, section, user_attrs, tags \\ []) do
    user_tag = tags[:user_tag] || random_tag()

    seeds
    |> create_user(user_attrs, tags)
    |> enroll_as_instructor(section, ref(user_tag))
  end

  def create_user(seeds, attrs, tags \\ []) do
    given_name = NameGenerator.first_name()
    family_name = NameGenerator.last_name()
    name = "#{given_name} #{family_name}"

    {:ok, user} =
      User.noauth_changeset(
        %User{
          sub: UUID.uuid4(),
          name: name,
          given_name: given_name,
          family_name: family_name,
          picture: "https://example.edu/user.jpg",
          email: "#{Slug.slugify(name)}@example.edu",
          locale: "en-US",
          independent_learner: false,
          age_verified: true
        },
        attrs
      )
      |> Repo.insert()

    seeds
    |> tag(tags[:user_tag], user)
  end

  def enroll_as_learner(seeds, section, user) do
    section = maybe_ref(section, seeds)
    user = maybe_ref(user, seeds)

    {:ok, %Enrollment{}} =
      Sections.enroll(user.id, section.id, [
        Lti_1p3.Tool.ContextRoles.get_role(:context_learner)
      ])

    seeds
  end

  defp enroll_as_instructor(seeds, section, user) do
    [section, user] = unpack(seeds, [section, user])

    {:ok, %Enrollment{}} =
      Sections.enroll(user.id, section.id, [
        Lti_1p3.Tool.ContextRoles.get_role(:context_instructor)
      ])

    seeds
  end

  def resolve(seeds, section, resource_id, tags) do
    [section] = unpack(seeds, [section])

    revision = DeliveryResolver.from_resource_id(section.slug, resource_id)

    seeds
    |> tag(tags[:revision_tag], revision)
  end
end
