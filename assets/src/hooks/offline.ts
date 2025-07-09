export const OfflineCacher = {
  mounted() {
    if (navigator.onLine) {
      const path = window.location.pathname;
      const html = document.documentElement.outerHTML;
      import("idb-keyval").then(({ set }) => {
        set(`offline-html:${path}`, html).then(() => {
          console.log(`[offline] Cached HTML after LiveView mount: ${path}`);
        });
      });
    }
  }
};
