/**
 * NavigationGuard hook — intercepts all navigation when there are unsaved changes.
 *
 * Combines two mechanisms:
 * 1. `beforeunload` — catches hard navigation (tab close, refresh, URL bar)
 * 2. Capture-phase click interception — catches LiveView navigation and standard links
 *    (sidebar, breadcrumbs, etc.) before LiveView processes them
 *
 * The element must have a `data-saved` attribute ("true" or "false") to indicate dirty state, or
 * a `data-dirty-form` selector: then the page is dirty when any `[data-scoring-edit]` control of that
 * form differs from its `data-initial` value (manual scoring page). In that mode the guard also
 * intercepts non-LiveView form submits (Sign Out, header forms), asks the server for the modal
 * without a target, and replays the original click or submit when the server answers
 * `unsaved_changes:proceed`.
 *
 * When unsaved changes exist and a link is clicked, this hook:
 * - Prevents the default navigation
 * - Pushes a `show_unsaved_changes_modal` event to the server with the target URL
 * - The server shows the UnsavedChangesModal with Save/Leave options
 */
export const NavigationGuard = {
  mounted(this: any) {
    const el = this.el as HTMLElement;

    const dirtyFormSelector = el?.dataset?.dirtyForm;

    const formIsDirty = (): boolean => {
      const form = dirtyFormSelector
        ? (document.querySelector(dirtyFormSelector) as HTMLFormElement | null)
        : null;
      if (!form) return false;
      return Array.from(
        form.querySelectorAll<HTMLInputElement | HTMLTextAreaElement>('[data-scoring-edit]'),
      ).some((input) => {
        if ((input as HTMLInputElement).validity?.badInput) return true;
        const initial = (input.dataset.initial ?? '').trim();
        return input.value.trim() !== initial;
      });
    };

    const hasDirtyState = (): boolean => {
      if (dirtyFormSelector) return formIsDirty();
      return el?.dataset?.saved !== 'true';
    };

    const lockForm = () => {
      const form = dirtyFormSelector
        ? (document.querySelector(dirtyFormSelector) as HTMLFormElement | null)
        : null;
      if (!form) return;
      form
        .querySelectorAll<HTMLInputElement | HTMLTextAreaElement>('[data-scoring-edit]')
        .forEach((input) => {
          input.readOnly = true;
        });
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
    this._bypass = false;

    this._clickListener = (e: MouseEvent) => {
      if (this._bypass) return;

      // Navigation links do nothing while the form's submit is in flight (`phx-submit-loading`).
      if (
        dirtyFormSelector &&
        e.target instanceof Element &&
        e.target.closest('[data-scoring-nav]')
      ) {
        const form = document.querySelector(dirtyFormSelector);
        if (form?.classList.contains('phx-submit-loading')) {
          e.preventDefault();
          e.stopPropagation();
          return;
        }
      }
      // Don't intercept modified clicks (Ctrl+click, Cmd+click, Shift+click, middle-click)
      if (e.defaultPrevented) return;
      if (e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;

      if (!hasDirtyState()) {
        // A patch link swaps in the next submission: lock edits so nothing typed meanwhile reaches it.
        if (dirtyFormSelector && e.target instanceof Element) {
          const patchLink = e.target.closest(
            'a[data-phx-link="patch"]',
          ) as HTMLAnchorElement | null;
          if (patchLink && patchLink.target !== '_blank' && !patchLink.hasAttribute('download')) {
            lockForm();
          }
        }
        return;
      }

      // Safely narrow event target — click targets can be non-Element nodes (e.g., Text)
      const target = e.target;
      if (!(target instanceof Element)) return;

      const link = target.closest('a[href]') as HTMLAnchorElement | null;
      if (!link) return;
      // In dirty-form mode data-method links become a form submit (phoenix_html.js:46-50) that the
      // submit listener guards; data-saved mode asks for its modal here, as before.
      if (dirtyFormSelector && link.hasAttribute('data-method')) return;

      const href = link.getAttribute('href');
      if (!href || href.startsWith('#') || href.startsWith('javascript:')) return;

      // Don't intercept links that open in new tabs
      if (link.target === '_blank') return;

      // Don't intercept download links
      if (link.hasAttribute('download')) return;

      // Don't intercept external links or non-http schemes (mailto:, tel:, etc.)
      try {
        const url = new URL(href, window.location.href);
        if (url.origin !== window.location.origin) return;
      } catch {
        return;
      }

      // Prevent navigation — stopPropagation is required to prevent LiveView's
      // own click handler on [data-phx-link] elements from processing the click
      e.preventDefault();
      e.stopPropagation();

      if (dirtyFormSelector) {
        // Replay mode — remember the element; the server only shows the modal.
        this._pending = { kind: 'click', el: link };
        this.pushEvent('show_unsaved_changes_modal', {});
        return;
      }

      // Push event to LiveView to show the unsaved changes modal
      this.pushEvent('show_unsaved_changes_modal', {
        target: href,
        reason: link.dataset.unsavedChangesReason || 'navigation',
      });
    };

    // Capture phase (true) ensures we fire before LiveView's click handler
    document.addEventListener('click', this._clickListener, true);

    if (dirtyFormSelector) {
      // aria-disabled mirrors that in-flight lock for assistive technology.
      const savingForm = document.querySelector(dirtyFormSelector);
      const syncSaving = () => {
        const saving = !!savingForm?.classList.contains('phx-submit-loading');
        document.querySelectorAll<HTMLElement>('[data-scoring-nav]').forEach((link) => {
          if (saving) {
            link.setAttribute('aria-disabled', 'true');
            link.dataset.savingDisabled = 'true';
          } else if (link.dataset.savingDisabled) {
            link.removeAttribute('aria-disabled');
            delete link.dataset.savingDisabled;
          }
        });
      };
      if (savingForm) {
        this._savingObserver = new MutationObserver(syncSaving);
        this._savingObserver.observe(savingForm, { attributes: true, attributeFilter: ['class'] });
        syncSaving();
      }

      // Non-LiveView form submits (Sign Out, header preferences, timezone) leave the page.
      this._submitListener = (e: SubmitEvent) => {
        if (this._bypass) return;
        const form = e.target as HTMLFormElement;
        if (!form || form.matches(dirtyFormSelector)) return;
        if (form.hasAttribute('phx-submit') || form.hasAttribute('phx-change')) return;
        if (!hasDirtyState()) return;
        e.preventDefault();
        e.stopPropagation();
        this._pending = { kind: 'submit', el: form };
        this.pushEvent('show_unsaved_changes_modal', {});
      };
      document.addEventListener('submit', this._submitListener, true);

      this.handleEvent('unsaved_changes:proceed', () => {
        const pending = this._pending;
        this._pending = null;
        if (!pending) return;
        this._bypass = true;
        // the draft is being discarded: make the form clean so beforeunload does not ask again
        const form = document.querySelector(dirtyFormSelector) as HTMLFormElement | null;
        form
          ?.querySelectorAll<HTMLInputElement | HTMLTextAreaElement>('[data-scoring-edit]')
          .forEach((i) => {
            i.value = i.dataset.initial ?? '';
          });
        // the replayed click bypasses the listener, so lock the form here when it is a patch link
        if (pending.kind === 'click' && pending.el.matches('a[data-phx-link="patch"]')) lockForm();
        if (pending.kind === 'click') pending.el.click();
        else (pending.el as HTMLFormElement).requestSubmit();
        setTimeout(() => {
          this._bypass = false;
        }, 0);
      });
    }
  },

  destroyed(this: any) {
    if (this._beforeUnloadListener) {
      window.removeEventListener('beforeunload', this._beforeUnloadListener);
    }
    if (this._clickListener) {
      document.removeEventListener('click', this._clickListener, true);
    }
    if (this._submitListener) {
      document.removeEventListener('submit', this._submitListener, true);
    }
    this._savingObserver?.disconnect();
  },
};
