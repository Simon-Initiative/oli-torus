defmodule Oli.Repo.Migrations.AddMatchingPartRegistration do
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
      'janus_matching',
      'janus_matching_authoring.js',
      'janus_matching_delivery.js',
      'Match items between two columns by drawing connecting lines',
      'janus-matching',
      'janus-matching',
      'icon-part-matching.svg',
      'Project Janus Team',
      'Matching',
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
    WHERE slug = 'janus_matching'
      AND delivery_element = 'janus-matching'
    """
  end
end
