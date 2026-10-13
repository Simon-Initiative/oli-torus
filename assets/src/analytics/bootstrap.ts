import { initializeAnalytics } from './index';

const script = document.currentScript as HTMLScriptElement | null;
if (script?.dataset.config) {
  let config: unknown;
  try {
    config = JSON.parse(script.dataset.config);
  } catch {
    config = null;
  }
  initializeAnalytics(config);
}
