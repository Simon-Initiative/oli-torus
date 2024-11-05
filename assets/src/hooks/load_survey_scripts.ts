export const LoadSurveyScripts = {
  mounted() {
    const elem = this.el as HTMLElement;
    const head = document.querySelectorAll('head')[0];
    this.handleEvent('load_survey_scripts', ({ script_sources }: { script_sources: string[] }) => {
      const scriptPromises: Promise<void>[] = script_sources.map(
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
              script.addEventListener('error', () => resolve());
              head.appendChild(script);
            } else {
              resolve();
            }
          }),
      );
      Promise.all(scriptPromises)
        .then(() => {
          window.OLI.initActivityBridge(elem.id);
          this.pushEventTo(`#${elem.id}`, 'survey_scripts_loaded');
        })
        .catch(() => {
          this.pushEventTo(`#${elem.id}`, 'survey_scripts_loaded', { error: true });
        });
    });
  },
};
