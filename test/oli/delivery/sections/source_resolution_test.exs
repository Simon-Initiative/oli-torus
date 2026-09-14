defmodule Oli.Delivery.Sections.SourceResolutionTest do
  use Oli.DataCase

  import Ecto.Query, warn: false
  import Oli.Factory

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Accounts.SystemRole
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.SectionSpecification
  alias Oli.Delivery.Sections.SourceResolution
  alias Oli.Delivery.Sections.SourceResolution.Actor

  setup do
    seed = Seeder.base_project_with_resource2()

    {:ok, source_section} =
      Sections.create_section(%{
        type: :enrollable,
        title: "An Existing Section",
        registration_open: true,
        context_id: UUID.uuid4(),
        base_project_id: seed.project.id
      })
      |> then(fn {:ok, section} -> section end)
      |> Sections.create_section_resources(seed.publication)

    {:ok, product} =
      Sections.create_section(%{
        type: :blueprint,
        title: "A Product",
        registration_open: true,
        context_id: UUID.uuid4(),
        base_project_id: seed.project.id,
        publisher_id: seed.project.publisher_id
      })
      |> then(fn {:ok, section} -> section end)
      |> Sections.create_section_resources(seed.publication)

    instructor = insert(:user)
    student = insert(:user)
    stranger = insert(:user)

    {:ok, _} =
      Sections.enroll(instructor.id, source_section.id, [
        ContextRoles.get_role(:context_instructor)
      ])

    {:ok, _} =
      Sections.enroll(student.id, source_section.id, [ContextRoles.get_role(:context_learner)])

    admin = insert(:author, system_role_id: SystemRole.role_id().system_admin)

    {:ok,
     Map.merge(seed, %{
       source_section: source_section,
       product: product,
       instructor: instructor,
       student: student,
       stranger: stranger,
       admin: admin,
       spec: SectionSpecification.direct()
     })}
  end

  describe "resolve/3 with section:<id>" do
    test "an instructor in the section can copy it", ctx do
      actor = Actor.new(ctx.instructor)

      assert {:ok, {:previous_section, section}} =
               SourceResolution.resolve("section:#{ctx.source_section.id}", actor, ctx.spec)

      assert section.id == ctx.source_section.id
    end

    test "an administrator can copy it", ctx do
      actor = Actor.new(nil, ctx.admin)

      assert {:ok, {:previous_section, _section}} =
               SourceResolution.resolve("section:#{ctx.source_section.id}", actor, ctx.spec)
    end

    test "a student enrolled in the section cannot copy it", ctx do
      actor = Actor.new(ctx.student)

      assert {:error, :not_found} =
               SourceResolution.resolve("section:#{ctx.source_section.id}", actor, ctx.spec)
    end

    test "an unrelated user guessing the id cannot copy it", ctx do
      actor = Actor.new(ctx.stranger)

      assert {:error, :not_found} =
               SourceResolution.resolve("section:#{ctx.source_section.id}", actor, ctx.spec)
    end

    test "an identityless request cannot copy it", ctx do
      assert {:error, :not_found} =
               SourceResolution.resolve(
                 "section:#{ctx.source_section.id}",
                 Actor.new(),
                 ctx.spec
               )
    end

    test "an explicitly trusted system actor can copy it", ctx do
      assert {:ok, {:previous_section, section}} =
               SourceResolution.resolve(
                 "section:#{ctx.source_section.id}",
                 Actor.system(),
                 ctx.spec
               )

      assert section.id == ctx.source_section.id
    end

    test "a nonexistent id is indistinguishable from an unauthorized one", ctx do
      actor = Actor.new(ctx.stranger)

      unauthorized =
        SourceResolution.resolve("section:#{ctx.source_section.id}", actor, ctx.spec)

      missing =
        SourceResolution.resolve("section:#{ctx.source_section.id + 100_000}", actor, ctx.spec)

      assert unauthorized == missing
      assert unauthorized == {:error, :not_found}
    end

    test "an archived source is not copyable", ctx do
      {:ok, _} = Sections.update_section(ctx.source_section, %{status: :archived})
      actor = Actor.new(ctx.instructor)

      assert {:error, :not_found} =
               SourceResolution.resolve("section:#{ctx.source_section.id}", actor, ctx.spec)
    end

    test "a product cannot be resolved through the section identifier", ctx do
      actor = Actor.new(nil, ctx.admin)

      assert {:error, :not_found} =
               SourceResolution.resolve("section:#{ctx.product.id}", actor, ctx.spec)
    end

    test "a malformed identifier is rejected", ctx do
      actor = Actor.new(nil, ctx.admin)

      assert {:error, :not_found} = SourceResolution.resolve("section:abc", actor, ctx.spec)
      assert {:error, :not_found} = SourceResolution.resolve("section:", actor, ctx.spec)
      assert {:error, :not_found} = SourceResolution.resolve("nonsense", actor, ctx.spec)
    end

    test "an LTI actor cannot copy a section from another institution", ctx do
      {:ok, source_section} =
        Sections.update_section(ctx.source_section, %{institution_id: ctx.institution.id})

      other_institution = insert(:institution)

      lti_spec = %SectionSpecification.Lti{
        lti_params: %{},
        institution: other_institution,
        registration: nil,
        deployment: nil
      }

      assert {:error, :not_found} =
               SourceResolution.resolve(
                 "section:#{source_section.id}",
                 Actor.new(ctx.instructor),
                 lti_spec
               )
    end

    test "an LTI actor cannot copy an institution-less section", ctx do
      lti_spec = %SectionSpecification.Lti{
        lti_params: %{},
        institution: ctx.institution,
        registration: nil,
        deployment: nil
      }

      assert is_nil(ctx.source_section.institution_id)

      assert {:error, :not_found} =
               SourceResolution.resolve(
                 "section:#{ctx.source_section.id}",
                 Actor.new(ctx.instructor),
                 lti_spec
               )
    end
  end

  describe "resolve/3 with product:<id>" do
    test "an administrator can resolve any product", ctx do
      actor = Actor.new(nil, ctx.admin)

      assert {:ok, {:product, product}} =
               SourceResolution.resolve("product:#{ctx.product.id}", actor, ctx.spec)

      assert product.id == ctx.product.id
    end

    test "a forged id from an unrelated user is refused", ctx do
      actor = Actor.new(ctx.stranger)

      assert {:error, :not_found} =
               SourceResolution.resolve("product:#{ctx.product.id}", actor, ctx.spec)
    end

    test "an identityless request is refused", ctx do
      assert {:error, :not_found} =
               SourceResolution.resolve("product:#{ctx.product.id}", Actor.new(), ctx.spec)
    end

    test "a forged id is refused with the same shape as a nonexistent one", ctx do
      actor = Actor.new(ctx.stranger)

      forged = SourceResolution.resolve("product:#{ctx.product.id}", actor, ctx.spec)
      missing = SourceResolution.resolve("product:#{ctx.product.id + 100_000}", actor, ctx.spec)

      assert forged == missing
      assert forged == {:error, :not_found}
    end

    test "an enrollable section cannot be resolved through the product identifier", ctx do
      actor = Actor.new(nil, ctx.admin)

      assert {:error, :not_found} =
               SourceResolution.resolve("product:#{ctx.source_section.id}", actor, ctx.spec)
    end

    test "an archived product is refused", ctx do
      {:ok, _} = Sections.update_section(ctx.product, %{status: :archived})
      actor = Actor.new(nil, ctx.admin)

      assert {:error, :not_found} =
               SourceResolution.resolve("product:#{ctx.product.id}", actor, ctx.spec)
    end
  end

  describe "resolve/3 with publication and project identifiers" do
    test "resolves a published publication", ctx do
      {:ok, publication} =
        ctx.publication
        |> Ecto.Changeset.change(%{
          published: DateTime.utc_now() |> DateTime.truncate(:second)
        })
        |> Repo.update()

      actor = Actor.new(nil, ctx.admin)

      assert {:ok, {:publication, resolved}} =
               SourceResolution.resolve("publication:#{publication.id}", actor, ctx.spec)

      assert resolved.id == publication.id
      assert resolved.project.id == ctx.project.id
    end

    test "refuses an unpublished publication", ctx do
      actor = Actor.new(nil, ctx.admin)

      assert is_nil(ctx.publication.published)

      assert {:error, :not_found} =
               SourceResolution.resolve("publication:#{ctx.publication.id}", actor, ctx.spec)
    end

    test "resolves an active project", ctx do
      actor = Actor.new(nil, ctx.admin)

      assert {:ok, {:project, project}} =
               SourceResolution.resolve("project:#{ctx.project.id}", actor, ctx.spec)

      assert project.id == ctx.project.id
    end

    test "refuses publication and project ids hidden from the actor", ctx do
      publication = publish(ctx.publication)
      actor = Actor.new(ctx.stranger)

      assert {:error, :not_found} =
               SourceResolution.resolve("publication:#{publication.id}", actor, ctx.spec)

      assert {:error, :not_found} =
               SourceResolution.resolve("project:#{ctx.project.id}", actor, ctx.spec)
    end

    test "resolves publication and project ids visible to the actor's institution", ctx do
      publication = publish(ctx.publication)

      project =
        ctx.project
        |> Project.changeset(%{visibility: :selected})
        |> Repo.update!()

      insert(:project_visibility,
        project_id: project.id,
        institution_id: ctx.institution.id,
        author_id: nil
      )

      matching_spec = lti_spec(ctx.institution)
      actor = Actor.new(ctx.stranger)

      assert {:ok, {:publication, _}} =
               SourceResolution.resolve(
                 "publication:#{publication.id}",
                 actor,
                 matching_spec
               )

      assert {:ok, {:project, _}} =
               SourceResolution.resolve("project:#{project.id}", actor, matching_spec)
    end

    test "refuses publication and project ids outside the actor's LTI institution", ctx do
      publication = publish(ctx.publication)

      project =
        ctx.project
        |> Project.changeset(%{visibility: :selected})
        |> Repo.update!()

      insert(:project_visibility,
        project_id: project.id,
        institution_id: ctx.institution.id,
        author_id: nil
      )

      other_spec = lti_spec(insert(:institution))
      actor = Actor.new(ctx.stranger)

      assert {:error, :not_found} =
               SourceResolution.resolve(
                 "publication:#{publication.id}",
                 actor,
                 other_spec
               )

      assert {:error, :not_found} =
               SourceResolution.resolve("project:#{project.id}", actor, other_spec)
    end

    test "refuses identityless publication and project requests", ctx do
      publication = publish(ctx.publication)
      actor = Actor.new()

      assert {:error, :not_found} =
               SourceResolution.resolve("publication:#{publication.id}", actor, ctx.spec)

      assert {:error, :not_found} =
               SourceResolution.resolve("project:#{ctx.project.id}", actor, ctx.spec)
    end

    test "allows an explicitly trusted system actor", ctx do
      publication = publish(ctx.publication)
      actor = Actor.system()

      assert {:ok, {:publication, _}} =
               SourceResolution.resolve("publication:#{publication.id}", actor, ctx.spec)

      assert {:ok, {:project, _}} =
               SourceResolution.resolve("project:#{ctx.project.id}", actor, ctx.spec)
    end

    test "refuses a missing project", ctx do
      actor = Actor.new(nil, ctx.admin)

      assert {:error, :not_found} =
               SourceResolution.resolve("project:#{ctx.project.id + 100_000}", actor, ctx.spec)
    end
  end

  describe "copyable_sections/2" do
    test "an instructor sees only sections they teach", ctx do
      assert [section] = SourceResolution.copyable_sections(Actor.new(ctx.instructor), ctx.spec)
      assert section.id == ctx.source_section.id
    end

    test "a student sees nothing", ctx do
      assert [] = SourceResolution.copyable_sections(Actor.new(ctx.student), ctx.spec)
    end

    test "an unrelated user sees nothing", ctx do
      assert [] = SourceResolution.copyable_sections(Actor.new(ctx.stranger), ctx.spec)
    end

    test "an administrator sees active enrollable sections but not products", ctx do
      sections = SourceResolution.copyable_sections(Actor.new(nil, ctx.admin), ctx.spec)

      ids = Enum.map(sections, & &1.id)

      assert ctx.source_section.id in ids
      refute ctx.product.id in ids
    end

    test "archived sections are excluded", ctx do
      {:ok, _} = Sections.update_section(ctx.source_section, %{status: :archived})

      assert [] = SourceResolution.copyable_sections(Actor.new(ctx.instructor), ctx.spec)
    end

    test "LTI source listings are scoped to the launch institution", ctx do
      {:ok, source_section} =
        Sections.update_section(ctx.source_section, %{institution_id: ctx.institution.id})

      other_institution = insert(:institution)

      matching_spec = %SectionSpecification.Lti{
        lti_params: %{},
        institution: ctx.institution,
        registration: nil,
        deployment: nil
      }

      other_spec = %{matching_spec | institution: other_institution}

      assert [section] =
               SourceResolution.copyable_sections(Actor.new(ctx.instructor), matching_spec)

      assert section.id == source_section.id
      assert [] = SourceResolution.copyable_sections(Actor.new(ctx.instructor), other_spec)
    end
  end

  describe "Actor.new/2" do
    test "derives admin status from the author system role", ctx do
      assert Actor.new(nil, ctx.admin).admin?
      refute Actor.new(ctx.instructor).admin?
    end

    test "does not treat an unloaded author association as an author" do
      # A user struct that has not been preloaded carries %NotLoaded{} here, which
      # is neither an author nor nil, and would otherwise flow into is_admin?/1.
      actor = Actor.new(%Oli.Accounts.User{id: 1})

      assert is_nil(actor.author)
      refute actor.admin?
    end

    test "uses a loaded author association when the caller passes none", ctx do
      actor = Actor.new(ctx.instructor)

      assert actor.author.id == ctx.instructor.author_id
      refute actor.admin?
    end

    test "identityless actors are not implicitly trusted" do
      refute Actor.system?(Actor.new())
      assert Actor.system?(Actor.system())
    end
  end

  defp publish(publication) do
    publication
    |> Ecto.Changeset.change(%{published: DateTime.utc_now() |> DateTime.truncate(:second)})
    |> Repo.update!()
  end

  defp lti_spec(institution) do
    %SectionSpecification.Lti{
      lti_params: %{},
      institution: institution,
      registration: nil,
      deployment: nil
    }
  end
end
