type InstructorPreviewCustomizationHook = {
  pushEvent: (
    event: string,
    payload: Record<string, unknown>,
    callback?: (reply: Record<string, unknown>) => void,
  ) => void;
  handlePreviewCustomization?: (event: Event) => void;
  handleFallbackPreviewCustomizationClick?: (event: Event) => void;
};

const validTargetKinds = new Set(['embedded_activity', 'bank_selection', 'bank_candidate']);
const validActions = new Set(['remove', 'restore']);

const isNumber = (value: unknown): value is number => typeof value === 'number';
const isString = (value: unknown): value is string => typeof value === 'string';

const isValidCustomizationDetail = (
  detail: unknown,
): detail is {
  action: 'remove' | 'restore';
  target: {
    kind: 'embedded_activity' | 'bank_selection' | 'bank_candidate';
    pageResourceId: number;
    activityResourceId?: number;
    selectionId?: string;
  };
} => {
  if (!detail || typeof detail !== 'object') {
    return false;
  }

  const candidate = detail as Record<string, unknown>;
  const target =
    candidate.target && typeof candidate.target === 'object'
      ? (candidate.target as Record<string, unknown>)
      : null;

  if (!target) {
    return false;
  }

  if (!isString(candidate.action) || !validActions.has(candidate.action)) {
    return false;
  }

  if (!isString(target.kind) || !validTargetKinds.has(target.kind)) {
    return false;
  }

  if (!isNumber(target.pageResourceId)) {
    return false;
  }

  switch (target.kind) {
    case 'embedded_activity':
      return isNumber(target.activityResourceId);

    case 'bank_selection':
      return isString(target.selectionId);

    case 'bank_candidate':
      return isString(target.selectionId) && isNumber(target.activityResourceId);

    default:
      return false;
  }
};

export const InstructorPreviewCustomization = {
  mounted(this: InstructorPreviewCustomizationHook) {
    // Some activity types still fall back to the authoring element during instructor preview.
    // Those cards are rendered fully on the server, so they cannot rely on the React preview
    // component's local state. This helper applies the LiveView reply directly to the fallback
    // wrapper so Remove/Restore stays aligned with the preview-component path. (The activity types
    // considered preview-capable by the server are listed in Oli.Activities.preview_supported_activity_slugs/0.)
    const updateFallbackPreviewCard = (
      target: {
        kind: 'embedded_activity' | 'bank_selection' | 'bank_candidate';
        pageResourceId: number;
        activityResourceId?: number;
        selectionId?: string;
      },
      reply: Record<string, unknown>,
    ) => {
      if (!reply.ok) {
        return;
      }

      const wrappers = document.querySelectorAll<HTMLElement>(
        '.instructor-preview-activity-wrapper',
      );

      wrappers.forEach((wrapper) => {
        const button = wrapper.querySelector<HTMLButtonElement>(
          '[data-preview-customization-button]',
        );

        if (!button) {
          return;
        }

        const encodedTarget = button.dataset.previewCustomizationTarget;

        if (!encodedTarget) {
          return;
        }

        try {
          const buttonTarget = JSON.parse(encodedTarget) as {
            kind: 'embedded_activity' | 'bank_selection' | 'bank_candidate';
            pageResourceId: number;
            activityResourceId?: number;
            selectionId?: string;
          };

          if (
            buttonTarget.kind !== target.kind ||
            buttonTarget.pageResourceId !== target.pageResourceId ||
            buttonTarget.activityResourceId !== target.activityResourceId ||
            buttonTarget.selectionId !== target.selectionId
          ) {
            return;
          }
        } catch {
          return;
        }

        const visualState = reply.visualState === 'removed' ? 'removed' : 'default';
        const isAuthoringFallback = wrapper.classList.contains(
          'instructor-preview-authoring-fallback',
        );

        wrapper.className =
          visualState === 'removed'
            ? `instructor-preview-activity-wrapper mb-6 rounded-lg border border-Border-border-default overflow-hidden p-6 relative instructor-preview-removed bg-Surface-surface-secondary-muted dark:bg-Background-bg-primary before:absolute before:inset-y-0 before:left-0 before:w-[6px] before:bg-Border-border-danger${
                isAuthoringFallback ? ' instructor-preview-authoring-fallback' : ''
              }`
            : `instructor-preview-activity-wrapper mb-6 rounded-lg border border-Border-border-default overflow-hidden p-6 instructor-preview-default bg-Surface-surface-primary${
                isAuthoringFallback ? ' instructor-preview-authoring-fallback' : ''
              }`;

        if (Array.isArray(reply.actions) && reply.actions.length > 0) {
          const action = reply.actions[0] as { kind?: string; label?: string };

          if (action.kind === 'remove' || action.kind === 'restore') {
            button.dataset.previewCustomizationAction = action.kind;
            button.className =
              action.kind === 'remove'
                ? 'inline-flex items-center gap-2 rounded-[6px] border bg-Surface-surface-primary px-4 py-2 font-open-sans text-[14px] font-semibold leading-4 tracking-normal shadow-[0px_2px_4px_rgba(0,52,99,0.10)] transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 border-Border-border-danger text-Specially-Tokens-Text-text-button-pill-muted hover:bg-[rgba(255,64,64,0.08)] dark:border-Border-border-danger dark:text-[#FFB5B7] dark:hover:bg-[rgba(255,64,64,0.18)] focus-visible:outline-Border-border-danger disabled:cursor-wait disabled:opacity-70'
                : 'inline-flex items-center gap-2 rounded-[6px] border bg-transparent px-4 py-2 font-open-sans text-[14px] font-semibold leading-4 tracking-normal shadow-[0px_2px_4px_rgba(0,52,99,0.10)] transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 border-[#8AB8E5] text-Text-text-button hover:bg-[#EEF6FF] hover:text-Text-text-button-hover dark:bg-transparent dark:border-[#4C82B8] dark:text-[#9FD0FF] dark:hover:bg-[#16395C] dark:hover:text-[#D7ECFF] focus-visible:outline-[#8AB8E5] disabled:cursor-wait disabled:opacity-70';

            const label = button.querySelector<HTMLElement>('[data-preview-customization-label]');
            if (label) {
              label.textContent = action.label ?? (action.kind === 'remove' ? 'Remove' : 'Restore');
            }

            button.innerHTML = `${
              action.kind === 'remove'
                ? '<svg aria-hidden="true" class="h-4 w-4" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M3 6H5H21" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"></path><path d="M19 6V20C19 20.5304 18.7893 21.0391 18.4142 21.4142C18.0391 21.7893 17.5304 22 17 22H7C6.46957 22 5.96086 21.7893 5.58579 21.4142C5.21071 21.0391 5 20.5304 5 20V6M8 6V4C8 3.46957 8.21071 2.96086 8.58579 2.58579C8.96086 2.21071 9.46957 2 10 2H14C14.5304 2 15.0391 2.21071 15.4142 2.58579C15.7893 2.96086 16 3.46957 16 4V6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"></path><path d="M10 11V17" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"></path><path d="M14 11V17" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"></path></svg>'
                : '<svg aria-hidden="true" class="h-4 w-4" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M3.33301 9.16667C3.33301 12.3883 5.94468 15 9.16634 15C12.388 15 14.9997 12.3883 14.9997 9.16667C14.9997 5.94501 12.388 3.33334 9.16634 3.33334C7.24384 3.33334 5.53848 4.2628 4.47595 5.69884" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"></path><path d="M5.00033 1.66666L5.00033 5.83332L9.16699 5.83332" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"></path></svg>'
            }<span data-preview-customization-label>${
              action.label ?? (action.kind === 'remove' ? 'Remove' : 'Restore')
            }</span>`;
          }
        }

        const titleRow = wrapper.querySelector<HTMLElement>('[data-preview-title-row]');
        const existingPill = wrapper.querySelector<HTMLElement>('[data-preview-status-pill]');
        const statusPill = reply.statusPill as { kind?: string; label?: string } | null | undefined;

        if (statusPill?.kind === 'removed') {
          const pillMarkup = `<span data-preview-status-pill class="inline-flex items-center rounded-full border border-Border-border-danger bg-[rgba(255,64,64,0.08)] px-4 py-1 font-open-sans text-[14px] font-semibold leading-4 tracking-normal text-[#C91414] dark:bg-[rgba(255,64,64,0.16)] dark:text-[#FFB5B7]">${
            statusPill.label ?? 'Removed'
          }</span>`;

          if (existingPill) {
            existingPill.outerHTML = pillMarkup;
          } else if (titleRow) {
            titleRow.insertAdjacentHTML('beforeend', pillMarkup);
          }
        } else if (existingPill) {
          existingPill.remove();
        }
      });
    };

    // Preview activities are custom elements hydrated by React, but the mutation authority stays
    // in LiveView. This hook is the bridge from browser-side preview actions back to the socket.
    this.handlePreviewCustomization = (event: Event) => {
      const detail = (event as CustomEvent).detail;

      if (!isValidCustomizationDetail(detail)) {
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

        updateFallbackPreviewCard(detail.target, reply);
      });
    };

    // Authoring-element fallbacks render their header actions directly in server HTML, so they
    // do not emit the custom browser event that React preview cards use. Delegate their clicks
    // here and forward the same payload shape into LiveView.
    this.handleFallbackPreviewCustomizationClick = (event: Event) => {
      const button = (event.target as HTMLElement | null)?.closest?.<HTMLButtonElement>(
        '[data-preview-customization-button]',
      );

      if (!button) {
        return;
      }

      const action = button.dataset.previewCustomizationAction;
      const encodedTarget = button.dataset.previewCustomizationTarget;

      if (!action || !encodedTarget) {
        return;
      }

      let target: {
        kind: 'embedded_activity' | 'bank_selection' | 'bank_candidate';
        pageResourceId: number;
        activityResourceId?: number;
        selectionId?: string;
      };

      try {
        target = JSON.parse(encodedTarget);
      } catch {
        return;
      }

      const detail = { action, target };

      if (!isValidCustomizationDetail(detail)) {
        return;
      }

      button.disabled = true;
      const label = button.querySelector<HTMLElement>('[data-preview-customization-label]');
      const previousLabel = label?.textContent ?? '';

      if (label) {
        label.textContent = 'Updating...';
      }

      this.pushEvent('toggle_preview_activity_customization', detail, (reply) => {
        button.disabled = false;

        if (!reply.ok && label) {
          label.textContent = previousLabel;
        }

        window.dispatchEvent(
          new CustomEvent('oli:preview-customization:reply', {
            detail: {
              ...detail,
              ...reply,
            },
          }),
        );

        updateFallbackPreviewCard(detail.target, reply);
      });
    };

    window.addEventListener('oli:preview-customization', this.handlePreviewCustomization);
    window.addEventListener('click', this.handleFallbackPreviewCustomizationClick as EventListener);
  },

  destroyed(this: InstructorPreviewCustomizationHook) {
    if (this.handlePreviewCustomization) {
      window.removeEventListener('oli:preview-customization', this.handlePreviewCustomization);
    }

    if (this.handleFallbackPreviewCustomizationClick) {
      window.removeEventListener(
        'click',
        this.handleFallbackPreviewCustomizationClick as EventListener,
      );
    }
  },
};
