import { onReady } from './ready';

// This callback page runs without the application layout or its dependencies.
onReady(() => {
  const element = document.getElementById('authoring-result');
  if (!element?.dataset.result) return;

  const result = JSON.parse(element.dataset.result);
  window.parent.postMessage(
    { type: 'lti_authoring_deep_link_response', ...result },
    window.location.origin,
  );
});
