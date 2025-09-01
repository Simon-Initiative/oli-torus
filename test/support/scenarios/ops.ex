defmodule Oli.Scenarios.Ops do
  @moduledoc """
  Operations that can be applied to course structures.
  """
  alias Oli.{Publishing}
  alias Oli.Resources.ResourceType
  alias Oli.Authoring.Editing.ContainerEditor
  alias Oli.Publishing.AuthoringResolver

  def apply_ops!(built_dest, ops) do
    # Always fetch the current working publication
    working_pub = Publishing.project_working_publication(built_dest.project.slug)
    dest_with_current_pub = %{built_dest | working_pub: working_pub}

    Enum.reduce(ops, {false, dest_with_current_pub}, fn op, {major?, dest} ->
      apply_op(op, major?, dest)
    end)
  end

  defp apply_op(%{"add_container" => params}, _major?, dest) do
    title = params["title"]
    # Default to root if not specified
    to = params["to"] || "root"
    {true, add_container!(dest, title, to)}
  end

  defp apply_op(%{"add_page" => params}, _major?, dest) do
    title = params["title"]
    # Default to root if not specified
    to = params["to"] || "root"
    {true, add_page!(dest, title, to)}
  end

  defp apply_op(%{"move" => params}, _major?, dest) do
    from = params["from"]
    to = params["to"] || "root"
    {true, move!(dest, from, to)}
  end

  defp apply_op(%{"reorder" => params}, _major?, dest) do
    from = params["from"]
    before = params["before"]
    after_target = params["after"]
    {true, reorder!(dest, from, before, after_target)}
  end

  defp apply_op(%{"remove" => %{"from" => title}}, _major?, dest) do
    {true, remove!(dest, title)}
  end

  defp apply_op(%{"revise" => params}, major?, dest) do
    target = params["target"]
    set = params["set"] || %{}
    {major?, revise!(dest, target, set)}
  end

  defp apply_op(_, major?, dest), do: {major?, dest}

  defp add_container!(dest, title, to) do
    %{project: proj} = dest
    author = dest.root.author

    # Determine parent revision (default to root if not specified)
    parent_rev =
      if to do
        dest.rev_by_title[to] || dest.root.revision
      else
        dest.root.revision
      end

    # Use ContainerEditor to create and attach the container
    attrs = %{
      objectives: %{"attached" => []},
      children: [],
      content: %{},
      title: title,
      graded: false,
      resource_type_id: ResourceType.id_for_container()
    }

    {:ok, cont_rev} = ContainerEditor.add_new(parent_rev, attrs, author, proj)

    # Get the updated parent revision
    parent_key = to || "root"
    updated_parent_rev = AuthoringResolver.from_resource_id(proj.slug, parent_rev.resource_id)

    %{
      dest
      | id_by_title: Map.put(dest.id_by_title, title, cont_rev.resource_id),
        rev_by_title:
          dest.rev_by_title
          |> Map.put(title, cont_rev)
          |> Map.put(parent_key, updated_parent_rev),
        root:
          if(parent_key == "root",
            do: %{dest.root | revision: updated_parent_rev},
            else: dest.root
          )
    }
  end

  defp add_page!(dest, title, to) do
    %{project: proj} = dest
    author = dest.root.author

    # Determine parent revision (default to root if not specified)
    parent_rev =
      if to do
        dest.rev_by_title[to] || dest.root.revision
      else
        dest.root.revision
      end

    # Use ContainerEditor to create and attach the page
    attrs = %{
      objectives: %{"attached" => []},
      children: [],
      content: %{"version" => "0.1.0", "model" => []},
      title: title,
      graded: false,
      max_attempts: 0,
      resource_type_id: ResourceType.id_for_page()
    }

    {:ok, page_rev} = ContainerEditor.add_new(parent_rev, attrs, author, proj)

    # Get the updated parent revision
    parent_key = to || "root"
    updated_parent_rev = AuthoringResolver.from_resource_id(proj.slug, parent_rev.resource_id)

    %{
      dest
      | id_by_title: Map.put(dest.id_by_title, title, page_rev.resource_id),
        rev_by_title:
          dest.rev_by_title
          |> Map.put(title, page_rev)
          |> Map.put(parent_key, updated_parent_rev),
        root:
          if(parent_key == "root",
            do: %{dest.root | revision: updated_parent_rev},
            else: dest.root
          )
    }
  end

  defp move!(dest, from_title, to_title) do
    %{project: proj} = dest
    author = dest.root.author

    source_id = dest.id_by_title[from_title]
    source_rev = dest.rev_by_title[from_title]
    new_parent_rev = dest.rev_by_title[to_title] || dest.root.revision

    if source_id && source_rev && new_parent_rev do
      # Check if already in the target parent
      if source_id in new_parent_rev.children do
        # Already attached, no need to move
        dest
      else
        # Find current parent
        old_parent_rev =
          Enum.find_value(dest.rev_by_title, fn {_title, rev} ->
            if rev.children && source_id in rev.children, do: rev
          end)

        # Use ContainerEditor.move_to to handle the move
        {:ok, _} =
          ContainerEditor.move_to(source_rev, old_parent_rev, new_parent_rev, author, proj)

        # Get updated parent revisions
        updated_new_parent =
          AuthoringResolver.from_resource_id(proj.slug, new_parent_rev.resource_id)

        # Update new parent in state
        updated_dest = %{
          dest
          | rev_by_title: Map.put(dest.rev_by_title, to_title || "root", updated_new_parent),
            root:
              if(to_title == "root" || to_title == nil,
                do: %{dest.root | revision: updated_new_parent},
                else: dest.root
              )
        }

        # Update old parent if it exists
        if old_parent_rev do
          old_parent_title =
            Enum.find_value(dest.rev_by_title, fn {title, rev} ->
              if rev.resource_id == old_parent_rev.resource_id, do: title
            end)

          if old_parent_title do
            updated_old_parent =
              AuthoringResolver.from_resource_id(proj.slug, old_parent_rev.resource_id)

            %{
              updated_dest
              | rev_by_title:
                  Map.put(updated_dest.rev_by_title, old_parent_title, updated_old_parent),
                root:
                  if(old_parent_title == "root",
                    do: %{updated_dest.root | revision: updated_old_parent},
                    else: updated_dest.root
                  )
            }
          else
            updated_dest
          end
        else
          updated_dest
        end
      end
    else
      dest
    end
  end

  defp reorder!(dest, from_title, before_title, after_title) do
    %{project: proj} = dest
    author = dest.root.author

    source_rev = dest.rev_by_title[from_title]

    if source_rev do
      # Find the container that holds this source
      parent_rev =
        Enum.find_value(dest.rev_by_title, fn {_title, rev} ->
          if rev.children && source_rev.resource_id in rev.children, do: rev
        end)

      if parent_rev do
        # Calculate target index based on before/after
        target_index =
          cond do
            before_title ->
              before_id = dest.id_by_title[before_title]

              case Enum.find_index(parent_rev.children, &(&1 == before_id)) do
                nil -> nil
                # Insert at the same index to go before
                idx -> idx
              end

            after_title ->
              after_id = dest.id_by_title[after_title]

              case Enum.find_index(parent_rev.children, &(&1 == after_id)) do
                nil -> nil
                # Insert after by going to next index
                idx -> idx + 1
              end

            true ->
              nil
          end

        if target_index do
          # Use ContainerEditor.reorder_child for the actual reordering
          {:ok, _} =
            ContainerEditor.reorder_child(parent_rev, proj, author, source_rev.slug, target_index)

          # Get updated parent revision
          parent_title =
            Enum.find_value(dest.rev_by_title, fn {title, rev} ->
              if rev.resource_id == parent_rev.resource_id, do: title
            end)

          updated_parent = AuthoringResolver.from_resource_id(proj.slug, parent_rev.resource_id)

          %{
            dest
            | rev_by_title: Map.put(dest.rev_by_title, parent_title || "root", updated_parent),
              root:
                if(parent_title == "root" || parent_title == nil,
                  do: %{dest.root | revision: updated_parent},
                  else: dest.root
                )
          }
        else
          dest
        end
      else
        dest
      end
    else
      dest
    end
  end

  defp remove!(dest, title) do
    %{project: proj} = dest
    _author = dest.root.author

    revision = dest.rev_by_title[title]

    if revision do
      # Find parent that contains this resource
      parent_info =
        Enum.find_value(dest.rev_by_title, fn {parent_title, parent_rev} ->
          if parent_rev.children && revision.resource_id in parent_rev.children do
            {parent_title, parent_rev}
          end
        end)

      case parent_info do
        {parent_title, parent_rev} ->
          # ContainerEditor.remove_child also marks the child as deleted,
          # which we don't actually want for reorganization. Instead,
          # just remove from parent's children list directly.
          new_children = Enum.filter(parent_rev.children, &(&1 != revision.resource_id))

          # Create new revision with updated children
          {:ok, updated_parent_rev} =
            Oli.Resources.create_revision_from_previous(
              parent_rev,
              %{children: new_children}
            )

          # Update published resource
          pub = Publishing.project_working_publication(proj.slug)

          Publishing.get_published_resource!(pub.id, parent_rev.resource_id)
          |> Publishing.update_published_resource(%{revision_id: updated_parent_rev.id})

          %{
            dest
            | id_by_title: Map.delete(dest.id_by_title, title),
              rev_by_title:
                dest.rev_by_title
                |> Map.delete(title)
                |> Map.put(parent_title, updated_parent_rev)
          }

        _ ->
          # Just remove from maps if not found in any parent
          %{
            dest
            | id_by_title: Map.delete(dest.id_by_title, title),
              rev_by_title: Map.delete(dest.rev_by_title, title)
          }
      end
    else
      dest
    end
  end

  defp revise!(dest, target, set_params) do
    %{project: proj} = dest
    rev = dest.rev_by_title[target]

    if rev do
      # Get author from the base structure
      author =
        if Map.has_key?(dest.root, :author), do: dest.root.author, else: dest.root.revision.author

      author_id = if is_map(author), do: author.id, else: author

      # Process the set parameters to convert special values
      revision_params =
        set_params
        |> Enum.map(fn {key, value} ->
          {key, process_revision_value(key, value)}
        end)
        |> Enum.into(%{})
        |> Map.put("author_id", author_id)

      # Use ContainerEditor.edit_page to make the changes
      case ContainerEditor.edit_page(proj, rev.slug, revision_params) do
        {:ok, _} ->
          # Fetch the updated revision from the database to ensure we have the latest version
          updated_rev = AuthoringResolver.from_resource_id(proj.slug, rev.resource_id)

          # Check if title was changed
          title_changed = Map.has_key?(set_params, "title") and set_params["title"] != target
          new_title = if title_changed, do: set_params["title"], else: target

          # Update our state with the new revision
          updated_rev_by_title = 
            if title_changed do
              dest.rev_by_title
              |> Map.delete(target)
              |> Map.put(new_title, updated_rev)
            else
              Map.put(dest.rev_by_title, target, updated_rev)
            end

          updated_id_by_title =
            if title_changed do
              resource_id = rev.resource_id
              dest.id_by_title
              |> Map.delete(target)
              |> Map.put(new_title, resource_id)
            else
              dest.id_by_title
            end

          updated_dest = %{
            dest
            | rev_by_title: updated_rev_by_title,
              id_by_title: updated_id_by_title
          }

          # Also update root if this was the root revision
          if target == "root" || rev.resource_id == dest.root.revision.resource_id do
            %{updated_dest | root: %{dest.root | revision: updated_rev}}
          else
            updated_dest
          end

        {:error, error} ->
          # If the update fails, raise an error to fail the test
          raise "Failed to revise '#{target}': #{inspect(error)}"
      end
    else
      # If the target revision is not found, raise an error to fail the test
      raise "Revision target '#{target}' not found in project"
    end
  end

  # Helper function to process special value formats (data-driven)
  defp process_revision_value(_key, value) when is_binary(value) do
    cond do
      # Handle @atom(...) format
      String.starts_with?(value, "@atom(") ->
        atom_str =
          value
          |> String.trim_leading("@atom(")
          |> String.trim_trailing(")")

        String.to_atom(atom_str)

      # Handle boolean strings
      value in ["true", "false"] ->
        value == "true"

      # Handle integer strings
      String.match?(value, ~r/^\d+$/) ->
        String.to_integer(value)

      # Handle float strings
      String.match?(value, ~r/^\d+\.\d+$/) ->
        String.to_float(value)

      # Otherwise keep as string
      true ->
        value
    end
  end

  defp process_revision_value(_key, value) when is_boolean(value), do: value
  defp process_revision_value(_key, value) when is_number(value), do: value
  defp process_revision_value(_key, value) when is_atom(value), do: value
  defp process_revision_value(_key, value), do: value
end
