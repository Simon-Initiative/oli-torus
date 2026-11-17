defmodule Oli.Authoring.Audited.Objectives do
  @moduledoc false

  # Learning objective commands of `Oli.Authoring.Audited`, which validates their arguments, and
  # the objective writes they run. Moved from `ObjectiveEditor`: `add_new/4`,
  # `add_new_parent_for_sub_objective/4`, `edit/4`, `delete/4`,
  # `remove_sub_objective_from_parent/4`, `delete_sub_objective/4`, and `detach_objective/3`, with
  # their private helpers. `ObjectiveEditor` keeps the reads, the detachment preview, and the
  # association checks the reads share.

  import Ecto.Query, warn: false
  import Oli.Utils

  import Oli.Authoring.Audited.Support,
    only: [latest_revisions: 2, lock_working_mappings: 2, record: 2, record_all: 2]

  alias Oli.Accounts.Author
  alias Oli.Auditing.Changes
  alias Oli.Authoring.{Broadcaster, Course}
  alias Oli.Authoring.Audited.{Activities, Pages}
  alias Oli.Authoring.Course.Project
  alias Oli.Authoring.Editing.{ActivityEditor, ObjectiveEditor, PageEditor}
  alias Oli.Publishing
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Repo
  alias Oli.Resources
  alias Oli.Resources.Revision

  @objective_fields %{title: :value, children: :value, deleted: :value}

  ## Commands

  def create_objective(context, attrs, author, project, container_slug) do
    project
    |> changing(
      context,
      slug_ids([container_slug]),
      fn -> add_new(attrs, author, project, container_slug) end,
      fn %{revision: revision} -> [revision.resource_id] end
    )
    |> tap(&broadcast_created(&1, project))
  end

  def link_sub_objective(context, slug, container_slug, project_slug, author) do
    case Course.get_project_by_slug(project_slug) do
      nil ->
        {:error, :not_found}

      project ->
        project
        |> changing(context, slug_ids([slug, container_slug]), fn ->
          add_new_parent_for_sub_objective(slug, container_slug, project_slug, author)
        end)
        |> tap(fn
          {:ok, revision} -> Broadcaster.broadcast_revision(revision, project_slug)
          _error -> :ok
        end)
    end
  end

  def edit_objective(context, revision_slug, attrs, author, project) do
    project
    |> changing(context, slug_ids([revision_slug]), fn ->
      edit(revision_slug, attrs, author, project)
    end)
    |> tap(fn
      {:ok, revision} -> Broadcaster.broadcast_resource(revision, project.slug)
      _error -> :ok
    end)
  end

  def delete_objective(context, revision_slug, author, project, parent_objective) do
    parent_ids =
      case parent_objective do
        %{resource_id: id} -> [id]
        nil -> []
      end

    project
    |> changing(context, slug_ids([revision_slug]) ++ parent_ids, fn ->
      delete(revision_slug, author, project, parent_objective)
    end)
    |> tap(fn
      {:ok, revision} ->
        Broadcaster.broadcast_resource(revision, project.slug)

        Enum.each(parent_ids, fn id ->
          project.slug
          |> AuthoringResolver.from_resource_id(id)
          |> Broadcaster.broadcast_resource(project.slug)
        end)

      _error ->
        :ok
    end)
  end

  def unlink_sub_objective(context, revision_slug, author, project, parent) do
    project
    |> changing(context, slug_ids([revision_slug, objective_slug(parent)]), fn ->
      remove_sub_objective_from_parent(revision_slug, author, project, parent)
    end)
    |> tap(fn
      {:ok, parent} -> Broadcaster.broadcast_resource(parent, project.slug)
      _error -> :ok
    end)
  end

  def delete_sub_objective(context, revision_slug, author, project, parent_slug) do
    project
    |> changing(context, slug_ids([revision_slug, parent_slug]), fn ->
      do_delete_sub_objective(revision_slug, author, project, parent_slug)
    end)
    |> case do
      {:ok, %{sub_objective: sub_objective, parent: parent}} ->
        Broadcaster.broadcast_resource(sub_objective, project.slug)
        Broadcaster.broadcast_resource(parent, project.slug)
        {:ok, sub_objective}

      error ->
        error
    end
  end

  # Locks the objectives' working mappings, reads them, runs `write`, and records each objective
  # that changed, including the ones `created` returns from the result.
  defp changing(project, context, resource_ids, write, created \\ fn _result -> [] end) do
    Repo.transaction(fn ->
      lock_working_mappings(project, resource_ids)
      before = latest_revisions(project, resource_ids)

      case write.() do
        {:ok, result} ->
          resource_ids = Enum.uniq(resource_ids ++ created.(result))
          after_state = latest_revisions(project, resource_ids)

          case record_all(
                 resource_ids,
                 &record_objective(context, project, before[&1], after_state[&1])
               ) do
            :ok -> result
            {:error, reason} -> Repo.rollback(reason)
          end

        {:error, reason} ->
          Repo.rollback(reason)

        other ->
          Repo.rollback(other)
      end
    end)
  end

  defp record_objective(_context, _project, _before, nil), do: :ok

  defp record_objective(context, project, before, %Revision{} = objective) do
    case Changes.diff(before, objective, fields(before, objective)) do
      changes when map_size(changes) == 0 ->
        :ok

      changes ->
        record(context, %{
          event_type: :learning_objectives_changed,
          entity:
            {:objective, objective.resource_id, %{title: objective.title, slug: objective.slug}},
          scope: %{project_id: project.id, resource_id: objective.resource_id},
          event_key: "objective:#{objective.resource_id}:changed",
          changes: changes
        })
    end
  end

  # A new objective records its title, and its sub-objectives when it starts with some.
  defp fields(nil, %Revision{children: children}) when children in [nil, []], do: %{title: :value}
  defp fields(nil, _objective), do: %{title: :value, children: :value}
  defp fields(_before, _objective), do: @objective_fields

  defp slug_ids(slugs) do
    Enum.flat_map(slugs, fn
      slug when slug in [nil, ""] ->
        []

      slug ->
        case Resources.get_resource_from_slug(slug) do
          nil -> []
          resource -> [resource.id]
        end
    end)
  end

  defp broadcast_created({:ok, %{revision: revision, container: container}}, project) do
    Broadcaster.broadcast_resource(revision, project.slug)

    if container != nil do
      Broadcaster.broadcast_resource(container, project.slug)
    end
  end

  defp broadcast_created(_error, _project), do: :ok

  ## Writes

  @doc """
  Creates a learning objective or sub-objective and optionally associates it with a parent.

  Passing a non-empty `container_slug` associates the new objective with that parent.
  """
  def add_new(attrs, %Author{} = author, %Project{} = project, container_slug \\ nil) do
    attrs =
      Map.merge(attrs, %{
        author_id: author.id,
        resource_type_id: Oli.Resources.ResourceType.id_for_objective()
      })

    result =
      Repo.transaction(fn ->
        with {:ok, %{resource: resource, revision: revision}} <-
               Oli.Authoring.Course.create_and_attach_resource(project, attrs),
             publication <- Publishing.project_working_publication(project.slug),
             {:ok, mapping} <- Publishing.upsert_published_resource(publication, revision),
             {:ok, container} <-
               maybe_append_to_container(
                 container_slug,
                 publication,
                 revision,
                 project.slug,
                 author
               ) do
          %{
            resource: resource,
            revision: revision,
            project: project,
            mapping: mapping,
            container: container
          }
        else
          error -> Repo.rollback(error)
        end
      end)

    result
  end

  @doc """
  Associates an active sub-objective with another objective in the working publication.

  The selected mappings are locked to prevent adding a reference to a child that
  is being deleted concurrently.
  """
  @spec add_new_parent_for_sub_objective(binary(), binary(), binary(), %Author{}) ::
          {:ok, %Revision{}} | {:error, :not_found | {:not_found}}
  def add_new_parent_for_sub_objective(slug, container_slug, project_slug, author) do
    result =
      Repo.transaction(fn ->
        publication = Publishing.project_working_publication(project_slug)

        revisions =
          ObjectiveEditor.objective_revisions(publication.id,
            slugs: [slug, container_slug],
            lock: true
          )

        with %{} = revision_to_attach <- Enum.find(revisions, &(&1.slug == slug)),
             %{} <- Enum.find(revisions, &(&1.slug == container_slug)),
             {:ok, revision} <-
               append_to_container(
                 container_slug,
                 publication,
                 revision_to_attach,
                 project_slug,
                 author
               ) do
          revision
        else
          nil -> Repo.rollback(:not_found)
          {:error, reason} -> Repo.rollback(reason)
        end
      end)

    result
  end

  def edit(revision_slug, attrs, %Author{} = author, %Project{} = project) do
    attrs =
      Map.merge(attrs, %{
        author_id: author.id
      })

    result =
      Repo.transaction(fn ->
        with {:ok, resource} <- Resources.get_resource_from_slug(revision_slug) |> trap_nil(),
             publication <- Publishing.project_working_publication(project.slug),
             {:ok, revision} <-
               Publishing.get_published_revision(publication.id, resource.id) |> trap_nil(),
             {:ok, new_revision} <- Resources.create_revision_from_previous(revision, attrs),
             {:ok, _} <- Publishing.upsert_published_resource(publication, new_revision) do
          new_revision
        else
          error -> Repo.rollback(error)
        end
      end)

    result
  end

  def delete(revision_slug, %Author{} = author, %Project{} = project, parent_objective \\ nil) do
    attrs = %{
      author_id: author.id,
      deleted: true
    }

    Repo.transaction(fn ->
      with {:ok, revision} <- edit(revision_slug, attrs, author, project) do
        if parent_objective != nil do
          edit(
            parent_objective.slug,
            %{
              children:
                Enum.filter(parent_objective.children, fn id -> id != revision.resource_id end)
            },
            author,
            project
          )
        end

        revision
      else
        error -> Repo.rollback(error)
      end
    end)
  end

  @doc """
  Unlinks a shared sub-objective from the selected parent.

  Only the selected parent and child mappings are locked. The transaction checks
  that another active parent remains, so unlinking cannot create an orphan.
  """
  @spec remove_sub_objective_from_parent(
          binary(),
          %Author{},
          %Project{},
          binary() | %{required(:slug) => binary()}
        ) ::
          {:ok, %Revision{}}
          | {:error,
             :last_association
             | :not_associated
             | :not_found
             | Ecto.Changeset.t()}
  def remove_sub_objective_from_parent(
        revision_slug,
        %Author{} = author,
        %Project{} = project,
        parent_objective_or_slug
      ) do
    parent_slug = objective_slug(parent_objective_or_slug)

    result =
      Repo.transaction(fn ->
        publication = Publishing.project_working_publication(project.slug)

        revisions =
          ObjectiveEditor.objective_revisions(publication.id,
            slugs: [revision_slug, parent_slug],
            lock: true
          )

        with {:ok, sub_objective, parent} <-
               ObjectiveEditor.associated_revisions(revisions, revision_slug, parent_slug),
             parent_ids <-
               Publishing.objective_parent_ids(sub_objective.resource_id, publication.id),
             true <- Enum.any?(parent_ids, &(&1 != parent.resource_id)),
             {:ok, updated_parent} <-
               unlink_from_parent(parent, sub_objective, publication, author) do
          updated_parent
        else
          false -> Repo.rollback(:last_association)
          {:error, reason} -> Repo.rollback(reason)
        end
      end)

    result
  end

  @doc """
  Deletes an untagged sub-objective and removes its final parent association.

  Only the selected child and parent mappings are locked, sharing the child lock
  with association creation so unrelated objective edits are not blocked.
  Parent associations and course-content references are rechecked within the
  transaction before deletion. Objective-association writers share the child
  mapping lock; course-content reference writers do not.
  """
  @spec do_delete_sub_objective(binary(), %Author{}, %Project{}, binary()) ::
          {:ok, %Revision{}}
          | {:error,
             :associated
             | :not_associated
             | :not_found
             | :tagged
             | Ecto.Changeset.t()}
  def do_delete_sub_objective(
        revision_slug,
        %Author{} = author,
        %Project{} = project,
        parent_slug
      ) do
    result =
      Repo.transaction(fn ->
        publication = Publishing.project_working_publication(project.slug)

        revisions =
          ObjectiveEditor.objective_revisions(publication.id,
            slugs: [revision_slug, parent_slug],
            lock: true
          )

        with {:ok, sub_objective, parent} <-
               ObjectiveEditor.associated_revisions(revisions, revision_slug, parent_slug),
             :ok <-
               ObjectiveEditor.final_association_eligibility(
                 sub_objective,
                 parent,
                 publication.id
               ),
             {:ok, deleted_sub_objective} <-
               Resources.create_revision_from_previous(sub_objective, %{
                 author_id: author.id,
                 deleted: true
               }),
             {:ok, _mapping} <-
               Publishing.upsert_published_resource(publication, deleted_sub_objective),
             {:ok, updated_parent} <-
               unlink_from_parent(parent, sub_objective, publication, author) do
          %{sub_objective: deleted_sub_objective, parent: updated_parent}
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)

    result
  end

  defp unlink_from_parent(parent, sub_objective, publication, author) do
    with {:ok, updated_parent} <-
           Resources.create_revision_from_previous(parent, %{
             author_id: author.id,
             children: Enum.reject(parent.children, &(&1 == sub_objective.resource_id))
           }),
         {:ok, _mapping} <- Publishing.upsert_published_resource(publication, updated_parent) do
      {:ok, updated_parent}
    end
  end

  defp objective_slug(%{slug: slug}), do: slug
  defp objective_slug(slug) when is_binary(slug), do: slug

  @doc """
  Detaches an objective from all unlocked pages and activites that currently reference it.

  Takes the objective revision slug, the project and the author that will be
  commiting the changes as arguments.
  """
  def detach_objective(context, objective_id, %Project{} = project, author) do
    case ObjectiveEditor.preview_objective_detatchment(objective_id, project) do
      %{attachments: {[], []}} ->
        []

      %{
        attachments: {pages, activities},
        locked_by: locked_by,
        parent_pages: parent_pages,
        locked_banked_activities: locked_banked_activities
      } ->
        # detach from all non-locked pages
        Enum.filter(pages, fn %{resource_id: resource_id} ->
          !Map.has_key?(locked_by, resource_id)
        end)
        |> Enum.each(fn %{slug: slug} ->
          detach_from_page(context, objective_id, slug, project.slug, author)
        end)

        # detach from all non-locked embedded activities. Locked activities are those activities
        # whose parent page is locked
        Enum.filter(activities, fn %{scope: scope} -> scope == "embedded" end)
        |> Enum.each(fn %{resource_id: resource_id} = activity ->
          case Map.get(parent_pages, resource_id) do
            nil ->
              if !Map.has_key?(locked_banked_activities, resource_id) do
                detach_from_banked_activity(context, objective_id, activity, project.slug, author)
              end

            %{id: page_id} ->
              if !Map.has_key?(locked_by, page_id) do
                page = AuthoringResolver.from_resource_id(project.slug, page_id)
                detach_from_activity(context, objective_id, page, activity, project.slug, author)
              end
          end
        end)

        # detach from all non-locked banked activities. Locked banked activities are those activities
        # that have a direct lock on them
        Enum.filter(activities, fn %{scope: scope} -> scope == "banked" end)
        |> Enum.filter(fn %{resource_id: resource_id} ->
          !Map.has_key?(locked_banked_activities, resource_id)
        end)
        |> Enum.each(fn activity ->
          detach_from_banked_activity(context, objective_id, activity, project.slug, author)
        end)
    end
  end

  # Specialized handling of detaching an objective from a page. The detachment
  # goes through the `PageEditor` so that locking and all other aspects of
  # manual detachment are simulated.
  defp detach_from_page(context, objective_id, page_slug, project_slug, author) do
    case PageEditor.acquire_lock(project_slug, page_slug, author.email) do
      {:acquired} ->
        case PageEditor.create_context(project_slug, page_slug, author) do
          # We need to create the context so that we get a client-side view of the
          # current objectives as slugs and not as ids.
          {:ok, %{objectives: objectives}} ->
            update = %{
              "objectives" => %{
                "attached" =>
                  Enum.filter(Map.get(objectives, "attached"), fn s -> s != objective_id end)
              }
            }

            result =
              case Pages.edit_page(
                     context,
                     project_slug,
                     page_slug,
                     author.email,
                     update
                   ) do
                {:ok, _} -> true
                _ -> false
              end

            PageEditor.release_lock(project_slug, page_slug, author.email)
            result

          _ ->
            PageEditor.release_lock(project_slug, page_slug, author.email)
            false
        end

      _ ->
        false
    end
  end

  # Detach an objective from all parts of an activity, using the `ActivityEditor` logic.
  defp detach_from_activity(
         context,
         objective_id,
         %{slug: page_slug, resource_id: page_id},
         %{slug: activity_slug, resource_id: activity_id},
         project_slug,
         author
       ) do
    case PageEditor.acquire_lock(project_slug, page_slug, author.email) do
      {:acquired} ->
        {:ok, %{objectives: objectives}} =
          ActivityEditor.create_context(project_slug, page_slug, activity_slug, author)

        update = %{
          "objectives" =>
            Enum.reduce(objectives, %{}, fn {p, a}, m ->
              Map.put(m, p, Enum.filter(a, fn s -> s != objective_id end))
            end)
        }

        Activities.edit_activity(
          context,
          project_slug,
          page_id,
          activity_id,
          author.email,
          update
        )

        PageEditor.release_lock(project_slug, page_slug, author.email)
    end
  end

  # Detach an objective from all parts of an activity, using the `ActivityEditor` logic.
  defp detach_from_banked_activity(
         context,
         objective_id,
         %{slug: activity_slug, resource_id: activity_id},
         project_slug,
         author
       ) do
    case PageEditor.acquire_lock(project_slug, activity_slug, author.email) do
      {:acquired} ->
        objectives = AuthoringResolver.from_resource_id(project_slug, activity_id).objectives

        update = %{
          "objectives" =>
            Enum.reduce(objectives, %{}, fn {p, a}, m ->
              Map.put(m, p, Enum.filter(a, fn s -> s != objective_id end))
            end)
        }

        Activities.edit_activity(
          context,
          project_slug,
          activity_id,
          activity_id,
          author.email,
          update
        )

        PageEditor.release_lock(project_slug, activity_slug, author.email)
    end
  end

  @spec maybe_append_to_container(nil | binary, any, any, any, any) ::
          {:error, {any}} | {:ok, atom | %{id: any, resource_id: integer}}
  defp maybe_append_to_container(
         container_slug,
         publication,
         revision_to_attach,
         project_slug,
         author
       ) do
    case container_slug do
      nil -> {:ok, nil}
      "" -> {:ok, nil}
      slug -> append_to_container(slug, publication, revision_to_attach, project_slug, author)
    end
  end

  defp append_to_container(container_slug, publication, revision_to_attach, _, author) do
    with {:ok, resource} <- Resources.get_resource_from_slug(container_slug) |> trap_nil(),
         {:ok, revision} <-
           Publishing.get_published_revision(publication.id, resource.id) |> trap_nil() do
      attrs = %{
        children: [revision_to_attach.resource_id | revision.children],
        author_id: author.id
      }

      {:ok, next} = Oli.Resources.create_revision_from_previous(revision, attrs)
      {:ok, _} = Publishing.upsert_published_resource(publication, next)
      {:ok, next}
    else
      error -> error
    end
  end
end
