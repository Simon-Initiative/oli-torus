defmodule Oli.Repo.Migrations.AddAccordionPartRegistration do
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
      'janus_accordion',
      'janus_accordion_authoring.js',
      'janus_accordion_delivery.js',
      'Collapsible content panels the learner can expand and collapse',
      'janus-accordion',
      'janus-accordion',
      '',
      'Project Janus Team',
      'Accordion',
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
    WHERE slug = 'janus_accordion'
      AND delivery_element = 'janus-accordion'
    """
  end
end
