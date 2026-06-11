type InstructorPreviewCustomizationHook = {
  pushEvent: (
    event: string,
    payload: Record<string, unknown>,
    callback?: (reply: Record<string, unknown>) => void,
  ) => void;
  handlePreviewCustomization?: (event: Event) => void;
};

export const InstructorPreviewCustomization = {
  mounted(this: InstructorPreviewCustomizationHook) {
    // Preview activities are custom elements hydrated by React, but the mutation authority stays
    // in LiveView. This hook is the bridge from browser-side preview actions back to the socket.
    this.handlePreviewCustomization = (event: Event) => {
      const detail = (event as CustomEvent).detail;

      if (!detail) {
        return;
      }

      // The pushEvent callback carries the per-component reply while the same handle_event can
      // still update normal LiveView assigns for the rest of the page.
      this.pushEvent('toggle_preview_activity_customization', detail, (reply) => {
        window.dispatchEvent(
          new CustomEvent('oli:preview-customization:reply', {
            detail: {
              ...detail,
              ...reply,
            },
          }),
        );
      });
    };

    window.addEventListener('oli:preview-customization', this.handlePreviewCustomization);
  },

  destroyed(this: InstructorPreviewCustomizationHook) {
    if (this.handlePreviewCustomization) {
      window.removeEventListener('oli:preview-customization', this.handlePreviewCustomization);
    }
  },
};
