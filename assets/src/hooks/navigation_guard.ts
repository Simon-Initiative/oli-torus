/**
 * NavigationGuard hook — intercepts all navigation when there are unsaved changes.
 *
 * Combines two mechanisms:
 * 1. `beforeunload` — catches hard navigation (tab close, refresh, URL bar)
 * 2. Capture-phase click interception — catches LiveView navigation and standard links
 *    (sidebar, breadcrumbs, etc.) before LiveView processes them
 *
 * The element must have a `data-saved` attribute ("true" or "false") to indicate dirty state.
 *
 * When unsaved changes exist and a link is clicked, this hook:
 * - Prevents the default navigation
 * - Pushes a `show_unsaved_changes_modal` event to the server with the target URL
 * - The server shows the UnsavedChangesModal with Save/Leave options
 */
export const NavigationGuard = {
  mounted(this: any) {
    const elementId = this.el?.id;

    const hasDirtyState = (): boolean => {
      const element = elementId ? document.getElementById(elementId) : null;
      return !!element && element.dataset.saved !== 'true';
    };

    // 1. Hard navigation guard (tab close, refresh, URL bar)
    this._beforeUnloadListener = (e: BeforeUnloadEvent) => {
      if (hasDirtyState()) {
        e.preventDefault();
        e.returnValue = '';
      }
    };
    window.addEventListener('beforeunload', this._beforeUnloadListener);

    // 2. Capture-phase click interception for all links
    this._clickListener = (e: MouseEvent) => {
      if (!hasDirtyState()) return;

      // Don't intercept modified clicks (Ctrl+click, Cmd+click, Shift+click, middle-click)
      if (e.defaultPrevented) return;
      if (e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;

      // Safely narrow event target — click targets can be non-Element nodes (e.g., Text)
      const target = e.target;
      if (!(target instanceof Element)) return;

      const link = target.closest('a[href]') as HTMLAnchorElement | null;
      if (!link) return;

      const href = link.getAttribute('href');
      if (!href || href === '#' || href.startsWith('javascript:')) return;

      // Don't intercept links that open in new tabs
      if (link.target === '_blank') return;

      // Don't intercept download links
      if (link.hasAttribute('download')) return;

      // Prevent the navigation
      e.preventDefault();
      e.stopPropagation();

      // Push event to LiveView to show the unsaved changes modal
      this.pushEvent('show_unsaved_changes_modal', { target: href });
    };

    // Capture phase (true) ensures we fire before LiveView's click handler
    document.addEventListener('click', this._clickListener, true);
  },

  destroyed(this: any) {
    if (this._beforeUnloadListener) {
      window.removeEventListener('beforeunload', this._beforeUnloadListener);
    }
    if (this._clickListener) {
      document.removeEventListener('click', this._clickListener, true);
    }
  },
};
