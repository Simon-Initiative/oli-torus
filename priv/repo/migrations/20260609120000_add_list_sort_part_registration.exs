defmodule Oli.Repo.Migrations.AddListSortPartRegistration do
  use Ecto.Migration

  def up do
    execute """
    INSERT INTO part_component_registrations (
      slug,
      authoring_script,
      delivery_script,
      description,
      authoring_element,
      delivery_element,
      icon,
      author,
      title,
      globally_available,
      inserted_at,
      updated_at
    )
    VALUES (
      'janus_list_sort',
      'janus_list_sort_authoring.js',
      'janus_list_sort_delivery.js',
      'A list of items that the learner reorders into the correct sequence.',
      'janus-list-sort',
      'janus-list-sort',
      'icon-part-list-sort.svg',
      'Project Janus Team',
      'List Sort',
      TRUE,
      NOW(),
      NOW()
    )
    ON CONFLICT (slug) DO UPDATE
    SET authoring_script = EXCLUDED.authoring_script,
        delivery_script = EXCLUDED.delivery_script,
        description = EXCLUDED.description,
        authoring_element = EXCLUDED.authoring_element,
        delivery_element = EXCLUDED.delivery_element,
        icon = EXCLUDED.icon,
        author = EXCLUDED.author,
        title = EXCLUDED.title,
        globally_available = EXCLUDED.globally_available,
        updated_at = NOW()
    """
  end

  def down do
    execute """
    DELETE FROM part_component_registrations
    WHERE slug = 'janus_list_sort'
      AND delivery_element = 'janus-list-sort'
    """
  end
end
