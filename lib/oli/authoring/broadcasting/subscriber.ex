defmodule Oli.Authoring.Broadcaster.Subscriber do
  alias Phoenix.PubSub
  import Oli.Authoring.Broadcaster.Messages

  ### Subscription API
  def subscribe_to_new_revisions(resource_id) do
    PubSub.subscribe(Oli.PubSub, message_new_revision(resource_id))
  end

  def subscribe_to_new_revisions_in_project(resource_id, project_slug) do
    PubSub.subscribe(Oli.PubSub, message_new_revisions_in_project(resource_id, project_slug))
  end

  def subscribe_to_new_resources(project_slug) do
    PubSub.subscribe(Oli.PubSub, message_new_resource(project_slug))
  end

  def subscribe_to_new_resources_of_type(resource_type_id, project_slug) do
    PubSub.subscribe(Oli.PubSub, message_new_resource_of_type(resource_type_id, project_slug))
  end

  def subscribe_to_new_publications(project_slug) do
    PubSub.subscribe(Oli.PubSub, message_new_publication(project_slug))
  end

  def subscribe_to_new_reviews(project_slug) do
    PubSub.subscribe(Oli.PubSub, message_new_review(project_slug))
  end

  def subscribe_to_warning_dismissals(project_slug) do
    PubSub.subscribe(Oli.PubSub, message_dismiss_warning(project_slug))
  end

  def subscribe_to_locks_acquired(project_slug, resource_id) do
    PubSub.subscribe(Oli.PubSub, message_lock_acquired(project_slug, resource_id))
  end

  def subscribe_to_locks_released(project_slug, resource_id) do
    PubSub.subscribe(Oli.PubSub, message_lock_released(project_slug, resource_id))
  end

  ### Unsubscription API
  def unsubscribe_to_new_revisions(resource_id) do
    PubSub.unsubscribe(Oli.PubSub, message_new_revision(resource_id))
  end

  def unsubscribe_to_new_revisions_in_project(resource_id, project_slug) do
    PubSub.unsubscribe(Oli.PubSub, message_new_revisions_in_project(resource_id, project_slug))
  end

  def unsubscribe_to_new_resources(project_slug) do
    PubSub.unsubscribe(Oli.PubSub, message_new_resource(project_slug))
  end

  def unsubscribe_to_new_resources_of_type(resource_type_id, project_slug) do
    PubSub.unsubscribe(Oli.PubSub, message_new_resource_of_type(resource_type_id, project_slug))
  end

  def unsubscribe_to_new_publications(project_slug) do
    PubSub.unsubscribe(Oli.PubSub, message_new_publication(project_slug))
  end

  def unsubscribe_to_new_reviews(project_slug) do
    PubSub.unsubscribe(Oli.PubSub, message_new_review(project_slug))
  end

  def unsubscribe_to_warning_dismissals(project_slug) do
    PubSub.unsubscribe(Oli.PubSub, message_dismiss_warning(project_slug))
  end

  def unsubscribe_to_locks_acquired(project_slug, resource_id) do
    PubSub.unsubscribe(Oli.PubSub, message_lock_acquired(project_slug, resource_id))
  end

  def unsubscribe_to_locks_released(project_slug, resource_id) do
    PubSub.unsubscribe(Oli.PubSub, message_lock_released(project_slug, resource_id))
  end
end
