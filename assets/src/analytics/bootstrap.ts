import { initializeAnalytics } from './index';

const script = document.currentScript as HTMLScriptElement | null;
if (script?.dataset.config) {
  initializeAnalytics(JSON.parse(script.dataset.config));
}
