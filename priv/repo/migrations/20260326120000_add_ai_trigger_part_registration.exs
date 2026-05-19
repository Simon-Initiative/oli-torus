defmodule Oli.Repo.Migrations.AddAiTriggerPartRegistration do
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
      'janus_ai_trigger',
      'janus_ai_trigger_authoring.js',
      'janus_ai_trigger_delivery.js',
      'An adaptive screen-level AI activation point for DOT.',
      'janus-ai-trigger',
      'janus-ai-trigger',
      'icon-AI.svg',
      'Project Janus Team',
      'AI Activation Point',
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
    WHERE slug = 'janus_ai_trigger'
      AND delivery_element = 'janus-ai-trigger'
    """
  end
end
