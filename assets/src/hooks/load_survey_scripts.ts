type LoadSurveyScriptsHook = {
  el: HTMLElement;
  pushEventTo: (selector: string, event: string, payload?: Record<string, unknown>) => void;
  handleEvent: (event: string, callback: (payload: { script_sources: string[] }) => void) => void;
};

export const LoadSurveyScripts = {
  mounted(this: LoadSurveyScriptsHook) {
    const elem = this.el;
    const head = document.head;

    const loadScriptsAndInit = (scriptSources: string[], notifyLoaded: boolean) => {
      const scriptPromises: Promise<void>[] = scriptSources.map(
        (source) =>
          new Promise<void>((resolve, reject) => {
            const isLoaded = Array.from(document.getElementsByTagName('script')).some((script) =>
              script.src.includes(source),
            );
            if (!isLoaded) {
              const script = document.createElement('script') as HTMLScriptElement;
              script.setAttribute('type', 'text/javascript');
              script.src = source;
              script.addEventListener('load', () => resolve());
              script.addEventListener('error', () =>
                reject(new Error(`Failed to load survey script: ${source}`)),
              );
              head.appendChild(script);
            } else {
              resolve();
            }
          }),
      );

      Promise.all(scriptPromises)
        .then(() => {
          const usePreviewActivityBridge = elem.dataset.previewActivityBridge === 'true';
          const initBridge = usePreviewActivityBridge
            ? window.OLI.initPreviewActivityBridge
            : window.OLI.initActivityBridge;

          initBridge(elem.id);

          if (notifyLoaded) {
            this.pushEventTo(`#${elem.id}`, 'survey_scripts_loaded');
          }
        })
        .catch(() => {
          if (notifyLoaded) {
            this.pushEventTo(`#${elem.id}`, 'survey_scripts_loaded', { error: true });
          }
        });
    };

    const inlineScriptSources = elem.dataset.scriptSources;

    if (inlineScriptSources) {
      try {
        loadScriptsAndInit(JSON.parse(inlineScriptSources), false);
      } catch {
        // Keep inline detail panes isolated from the parent LiveView.
      }
    }

    this.handleEvent('load_survey_scripts', ({ script_sources }: { script_sources: string[] }) => {
      loadScriptsAndInit(script_sources, true);
    });
  },
};
