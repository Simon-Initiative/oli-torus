defmodule Oli.Repo.Migrations.AddItemBankPartRegistration do
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
      'janus_item_bank',
      'janus_item_bank_authoring.js',
      'janus_item_bank_delivery.js',
      'Sort items from an item bank into one or more categories',
      'janus-item-bank',
      'janus-item-bank',
      'icon-part-item-bank.svg',
      'Project Janus Team',
      'Item Bank',
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
    WHERE slug = 'janus_item_bank'
      AND delivery_element = 'janus-item-bank'
    """
  end
end
