defmodule Oli.Utils.Seeder.Section do
  import Ecto.Query, warn: false

  import Oli.Utils.Seeder.Utils

  alias Oli.Repo
  alias Oli.Accounts.User
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Enrollment
  alias Oli.Delivery.Gating
  alias Oli.Utils.DataGenerators.NameGenerator
  alias Oli.Utils.Slug
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Conversation

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
        instructor \\ nil,
        institution \\ nil,
        attrs \\ %{},
        tags \\ []
      ) do
    [product, instructor, institution] = unpack(seeds, [product, instructor, institution])

    section_tag = tags[:section_tag] || :section

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
    |> tag(section_tag, section)
  end

  def create_and_enroll_learner(seeds, section, user_attrs \\ %{}, tags \\ []) do
    user_tag = tags[:user_tag] || random_tag("user")

    seeds
    |> create_user(user_attrs, Keyword.put(tags, :user_tag, user_tag))
    |> enroll_as_learner(section, ref(user_tag))
  end

  def create_and_enroll_instructor(seeds, section, user_attrs \\ %{}, tags \\ []) do
    user_tag = tags[:user_tag] || random_tag("user")

    seeds
    |> create_user(user_attrs, Keyword.put(tags, :user_tag, user_tag))
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
        Lti_1p3.Roles.ContextRoles.get_role(:context_learner)
      ])

    seeds
  end

  defp enroll_as_instructor(seeds, section, user) do
    [section, user] = unpack(seeds, [section, user])

    {:ok, %Enrollment{}} =
      Sections.enroll(user.id, section.id, [
        Lti_1p3.Roles.ContextRoles.get_role(:context_instructor)
      ])

    seeds
  end

  def resolve(seeds, section, resource_id, tags) do
    [section] = unpack(seeds, [section])

    revision = DeliveryResolver.from_resource_id(section.slug, resource_id)

    seeds
    |> tag(tags[:revision_tag], revision)
  end

  def ensure_user_visit(seeds, user, section) do
    [user, section] = unpack(seeds, [user, section])

    case Sections.Enrollment
         |> where([e], e.user_id == ^user.id and e.section_id == ^section.id)
         |> limit(1)
         |> Repo.one() do
      nil ->
        throw("User #{user.id} is not enrolled in section #{section.id}")

      enrollment ->
        enrollment
        |> Sections.Enrollment.changeset(%{state: %{has_visited_once: true}})
        |> Repo.update()
    end

    seeds
  end

  def create_schedule_gating_condition(
        seeds,
        section,
        revision,
        start_datetime,
        end_datetime,
        tags \\ []
      ) do
    [section, revision] = unpack(seeds, [section, revision])

    {:ok, gating_condition} =
      Gating.create_gating_condition(%{
        type: :schedule,
        data: %{
          start_datetime: start_datetime,
          end_datetime: end_datetime
        },
        resource_id: revision.resource_id,
        section_id: section.id
      })

    seeds
    |> tag(tags[:gating_condition_tag], gating_condition)
  end

  def add_assistant_conversation_message(
        seeds,
        section,
        user,
        revision,
        role,
        message_content,
        tags \\ []
      ) do
    [section, user, revision] = unpack(seeds, [section, user, revision])

    attrs =
      Conversation.Message.new(
        role,
        message_content
      )
      |> Map.from_struct()
      |> Map.merge(%{
        user_id: user.id,
        resource_id: maybe_resource_id(revision),
        section_id: section.id
      })

    {:ok, cm} =
      %Conversation.ConversationMessage{}
      |> Conversation.ConversationMessage.changeset(attrs)
      |> Repo.insert()

    seeds
    |> tag(tags[:message_tag], cm)
  end

  defp maybe_resource_id(revision) do
    case revision do
      nil -> nil
      _ -> revision.resource_id
    end
  end
end
