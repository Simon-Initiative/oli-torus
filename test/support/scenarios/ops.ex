defmodule Oli.Scenarios.Ops do
  @moduledoc """
  Operations that can be applied to course structures.
  """
  alias Oli.{Publishing, Seeder, Resources}

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
    parent_title = params["parent"]
    {true, add_container!(dest, title, parent_title)}
  end

  defp apply_op(%{"add_page" => params}, _major?, dest) do
    title = params["title"]
    parent_title = params["parent"] || "root"
    {true, add_page!(dest, title, parent_title)}
  end

  defp apply_op(%{"attach" => params}, _major?, dest) do
    child_title = params["child"]
    parent_title = params["parent"] || "root"
    position = params["position"] || "end"
    {true, attach!(dest, child_title, parent_title, position)}
  end

  defp apply_op(%{"reorder_children" => params}, _major?, dest) do
    parent_title = params["parent"] || "root"
    order = params["order"]
    {true, reorder_children!(dest, parent_title, order)}
  end

  defp apply_op(%{"remove" => %{"target" => title}}, _major?, dest) do
    {true, remove!(dest, title)}
  end

  defp apply_op(%{"edit_page_title" => params}, major?, dest) do
    old_title = params["title"]
    new_title = params["new_title"]
    {major?, edit_title_minor!(dest, old_title, new_title)}
  end

  defp apply_op(_, major?, dest), do: {major?, dest}

  defp add_container!(dest, title, parent_title) do
    %{project: proj, working_pub: pub} = dest
    author = dest.root.author
    
    %{resource: res, revision: rev} = 
      Seeder.create_container(title, pub, proj, author)
    
    # Add container to maps
    dest_with_container = put_in_maps(dest, title, res.id, rev)
    
    # Attach to parent if specified
    if parent_title do
      parent_id = dest_with_container.id_by_title[parent_title]
      parent_rev = dest_with_container.rev_by_title[parent_title]
      
      if parent_id && parent_rev do
        parent_res = %{id: parent_id}
        updated_parent_rev = Seeder.attach_pages_to([res], parent_res, parent_rev, pub)
        
        # Update the parent revision in our maps
        %{dest_with_container | 
          rev_by_title: Map.put(dest_with_container.rev_by_title, parent_title, updated_parent_rev),
          root: if(parent_title == "root", do: %{dest_with_container.root | revision: updated_parent_rev}, else: dest_with_container.root)
        }
      else
        dest_with_container
      end
    else
      dest_with_container
    end
  end

  defp add_page!(dest, title, parent_title) do
    %{project: proj, working_pub: pub} = dest
    author = dest.root.author
    
    %{resource: res, revision: rev} = 
      Seeder.create_page(title, pub, proj, author)
    
    # Attach to parent if specified
    dest_with_page = put_in_maps(dest, title, res.id, rev)
    
    if parent_title do
      parent_id = dest_with_page.id_by_title[parent_title]
      parent_rev = dest_with_page.rev_by_title[parent_title]
      
      if parent_id && parent_rev do
        parent_res = %{id: parent_id}
        updated_parent_rev = Seeder.attach_pages_to([res], parent_res, parent_rev, pub)
        
        # Update the parent revision in our maps
        %{dest_with_page | 
          rev_by_title: Map.put(dest_with_page.rev_by_title, parent_title, updated_parent_rev),
          root: if(parent_title == "root", do: %{dest_with_page.root | revision: updated_parent_rev}, else: dest_with_page.root)
        }
      else
        dest_with_page
      end
    else
      dest_with_page
    end
  end

  defp attach!(dest, child_title, parent_title, _position) do
    %{working_pub: pub} = dest
    
    child_id = dest.id_by_title[child_title]
    parent_id = dest.id_by_title[parent_title]
    parent_rev = dest.rev_by_title[parent_title]
    
    if child_id && parent_id && parent_rev do
      child_res = %{id: child_id}
      parent_res = %{id: parent_id}
      
      # Remove from current parent if exists, then attach to new parent
      updated_parent_rev = Seeder.attach_pages_to([child_res], parent_res, parent_rev, pub)
      
      %{dest | rev_by_title: Map.put(dest.rev_by_title, parent_title, updated_parent_rev)}
    else
      dest
    end
  end

  defp reorder_children!(dest, parent_title, order) do
    %{working_pub: pub} = dest
    
    parent_id = dest.id_by_title[parent_title]
    parent_rev = dest.rev_by_title[parent_title]
    
    if parent_id && parent_rev do
      # Map titles to IDs
      ordered_ids = 
        order
        |> Enum.map(fn title -> dest.id_by_title[title] end)
        |> Enum.filter(& &1)
      
      if Enum.any?(ordered_ids) do
        _parent_res = %{id: parent_id}
        
        # Update the container's children via revision
        {:ok, updated_rev} = Resources.create_revision_from_previous(
          parent_rev, 
          %{children: ordered_ids}
        )
        
        # Update published resource
        Publishing.get_published_resource!(pub.id, parent_id)
        |> Publishing.update_published_resource(%{revision_id: updated_rev.id})
        
        %{dest | rev_by_title: Map.put(dest.rev_by_title, parent_title, updated_rev)}
      else
        dest
      end
    else
      dest
    end
  end

  defp remove!(dest, title) do
    %{working_pub: pub} = dest
    
    resource_id = dest.id_by_title[title]
    
    if resource_id do
      # Find parent that contains this resource
      parent_info = 
        Enum.find_value(dest.rev_by_title, fn {parent_title, parent_rev} ->
          if parent_rev.children && resource_id in parent_rev.children do
            {parent_title, parent_rev}
          end
        end)
      
      case parent_info do
        {parent_title, parent_rev} ->
          parent_id = dest.id_by_title[parent_title]
          _parent_res = %{id: parent_id}
          
          # Remove from parent's children
          new_children = Enum.filter(parent_rev.children, & &1 != resource_id)
          # Update container children via revision
          {:ok, updated_rev} = Resources.create_revision_from_previous(
            parent_rev,
            %{children: new_children}
          )
          
          # Update published resource
          Publishing.get_published_resource!(pub.id, parent_id)
          |> Publishing.update_published_resource(%{revision_id: updated_rev.id})
          
          %{dest | 
            id_by_title: Map.delete(dest.id_by_title, title),
            rev_by_title: dest.rev_by_title 
                         |> Map.delete(title)
                         |> Map.put(parent_title, updated_rev)
          }
        
        _ -> 
          # Just remove from maps if not found in any parent
          %{dest | 
            id_by_title: Map.delete(dest.id_by_title, title),
            rev_by_title: Map.delete(dest.rev_by_title, title)
          }
      end
    else
      dest
    end
  end

  defp edit_title_minor!(dest, old_title, new_title) do
    id = dest.id_by_title[old_title]
    rev = dest.rev_by_title[old_title]
    
    if id && rev do
      # Update the revision's title
      %{working_pub: pub} = dest
      # Get author from the base structure
      author = if Map.has_key?(dest.root, :author), do: dest.root.author, else: dest.root.revision.author
      author_id = if is_map(author), do: author.id, else: author
      
      updated_rev = Publishing.publish_new_revision(
        rev,
        %{title: new_title},
        pub,
        author_id
      )
      
      %{dest |
        id_by_title: dest.id_by_title |> Map.delete(old_title) |> Map.put(new_title, id),
        rev_by_title: dest.rev_by_title |> Map.delete(old_title) |> Map.put(new_title, updated_rev)
      }
    else
      dest
    end
  end

  defp put_in_maps(dest, title, id, rev) do
    %{dest |
      id_by_title: Map.put(dest.id_by_title, title, id),
      rev_by_title: Map.put(dest.rev_by_title, title, rev)
    }
  end
end