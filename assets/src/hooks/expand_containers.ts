export const ExpandContainers = {
  mounted() {
    const expandHandler = (e: Event) => {
      const ids = (e as CustomEvent).detail.ids as number[] | undefined;
      if (!ids || ids.length === 0) return;

      ids.forEach((id) => {
        const button = document.querySelector<HTMLButtonElement>(
          `button[aria-expanded='false'][data-bs-toggle='collapse'][phx-value-id='${id}']`,
        );

        button?.click();
      });
    };

    window.addEventListener('phx:expand-containers', expandHandler);

    this.destroy = () => {
      window.removeEventListener('phx:expand-containers', expandHandler);
    };
  },

  destroyed() {
    this.destroy?.();
  },
};
