import type { PreviewCustomizationTarget } from 'components/activities/types';
import type {
  PreviewCustomizationReply,
  PreviewCustomizationState,
} from 'components/instructor_preview/preview_customization_store';
import {
  clearFallbackPreviewCustomizationStore,
  getPreviewCustomizationCopy,
  getPreviewCustomizationStore,
} from 'components/instructor_preview/preview_customization_store';

type InstructorPreviewCustomizationHook = {
  el: HTMLElement;
  pushEvent: (
    event: string,
    payload: Record<string, unknown>,
    callback?: (reply: unknown) => void,
  ) => void;
  handleEvent: (event: string, callback: (payload: unknown) => void) => void;
  handlePreviewCustomization?: (event: Event) => void;
  handleFallbackPreviewCustomizationClick?: (event: Event) => void;
  previewCustomizationPageIds?: Set<number>;
};

const validTargetKinds = new Set(['embedded_activity', 'bank_selection', 'bank_candidate']);
const validActions = new Set(['remove', 'restore']);

const isNumber = (value: unknown): value is number => typeof value === 'number';
const isString = (value: unknown): value is string => typeof value === 'string';
const isRecord = (value: unknown): value is Record<string, unknown> =>
  Boolean(value) && typeof value === 'object';

const isValidCustomizationTarget = (value: unknown): value is PreviewCustomizationTarget => {
  if (!isRecord(value)) {
    return false;
  }

  if (!isString(value.kind) || !validTargetKinds.has(value.kind)) {
    return false;
  }

  if (!isNumber(value.pageResourceId)) {
    return false;
  }

  if (value.activityResourceId !== undefined && !isNumber(value.activityResourceId)) {
    return false;
  }

  if (value.selectionId !== undefined && !isString(value.selectionId)) {
    return false;
  }

  switch (value.kind) {
    case 'embedded_activity':
      return isNumber(value.activityResourceId);

    case 'bank_selection':
      return isString(value.selectionId);

    case 'bank_candidate':
      return isString(value.selectionId) && isNumber(value.activityResourceId);

    default:
      return false;
  }
};

const isValidCustomizationReply = (value: unknown): value is PreviewCustomizationReply => {
  if (!isRecord(value) || typeof value.ok !== 'boolean') {
    return false;
  }

  if (value.target !== undefined && !isValidCustomizationTarget(value.target)) {
    return false;
  }

  if (
    value.disposition !== undefined &&
    value.disposition !== 'included' &&
    value.disposition !== 'removed'
  ) {
    return false;
  }

  if (
    value.visualState !== undefined &&
    value.visualState !== null &&
    value.visualState !== 'default' &&
    value.visualState !== 'removed'
  ) {
    return false;
  }

  return value.availableCount === undefined || isNumber(value.availableCount);
};

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
  if (!isRecord(detail)) {
    return false;
  }

  if (!isString(detail.action) || !validActions.has(detail.action)) {
    return false;
  }

  return isValidCustomizationTarget(detail.target);
};

export const InstructorPreviewCustomization = {
  mounted(this: InstructorPreviewCustomizationHook) {
    this.previewCustomizationPageIds = new Set<number>();
    const copy = getPreviewCustomizationCopy();
    const statusRegion = this.el.querySelector<HTMLElement>('[data-preview-customization-status]');
    const announcePendingUpdate = () => {
      if (statusRegion) {
        statusRegion.textContent = copy.pendingAnnouncement;
      }
    };
    const clearPendingAnnouncement = () => {
      if (statusRegion) {
        statusRegion.textContent = '';
      }
    };
    const storeForPage = (pageResourceId: number) => {
      this.previewCustomizationPageIds?.add(pageResourceId);
      return getPreviewCustomizationStore(pageResourceId);
    };

    const previewActionButtonClass = (kind: 'remove' | 'restore', disabled: boolean) => {
      const shared =
        'inline-flex items-center gap-2 rounded-[6px] border bg-Surface-surface-primary px-4 py-2 font-open-sans text-[14px] font-semibold leading-4 tracking-normal shadow-[0px_2px_4px_rgba(0,52,99,0.10)] transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 disabled:pointer-events-none';

      if (disabled) {
        return `${shared} border-Fill-Accent-fill-accent-muted text-Text-text-low-alpha`;
      }

      return kind === 'remove'
        ? `${shared} border-Border-border-danger text-Specially-Tokens-Text-text-button-pill-muted hover:bg-[rgba(255,64,64,0.08)] dark:border-Border-border-danger dark:text-[#FFB5B7] dark:hover:bg-[rgba(255,64,64,0.18)] focus-visible:outline-Border-border-danger`
        : `${shared} bg-transparent border-[#8AB8E5] text-Text-text-button hover:bg-[#EEF6FF] hover:text-Text-text-button-hover dark:bg-transparent dark:border-[#4C82B8] dark:text-[#9FD0FF] dark:hover:bg-[#16395C] dark:hover:text-[#D7ECFF] focus-visible:outline-[#8AB8E5]`;
    };

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
      state: PreviewCustomizationState,
    ) => {
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

        const showRemovedTreatment =
          state.disposition === 'removed' && target.kind !== 'bank_candidate';
        const visualState = showRemovedTreatment ? 'removed' : 'default';
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

        const action = state.disposition === 'removed' ? 'restore' : 'remove';
        const disabled = !state.canToggle || state.pendingAction !== null;
        const isPending = state.pendingAction !== null;
        button.dataset.previewCustomizationAction = action;
        button.disabled = disabled;
        button.setAttribute('aria-busy', String(isPending));
        button.className = previewActionButtonClass(action, disabled);

        button.innerHTML = `${
          action === 'remove'
            ? '<svg aria-hidden="true" class="h-4 w-4" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M3 6H5H21" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"></path><path d="M19 6V20C19 20.5304 18.7893 21.0391 18.4142 21.4142C18.0391 21.7893 17.5304 22 17 22H7C6.46957 22 5.96086 21.7893 5.58579 21.4142C5.21071 21.0391 5 20.5304 5 20V6M8 6V4C8 3.46957 8.21071 2.96086 8.58579 2.58579C8.96086 2.21071 9.46957 2 10 2H14C14.5304 2 15.0391 2.21071 15.4142 2.58579C15.7893 2.96086 16 3.46957 16 4V6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"></path><path d="M10 11V17" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"></path><path d="M14 11V17" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"></path></svg>'
            : '<svg aria-hidden="true" class="h-4 w-4" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M3.33301 9.16667C3.33301 12.3883 5.94468 15 9.16634 15C12.388 15 14.9997 12.3883 14.9997 9.16667C14.9997 5.94501 12.388 3.33334 9.16634 3.33334C7.24384 3.33334 5.53848 4.2628 4.47595 5.69884" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"></path><path d="M5.00033 1.66666L5.00033 5.83332L9.16699 5.83332" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"></path></svg>'
        }<span data-preview-customization-label></span>`;

        const label = button.querySelector<HTMLElement>('[data-preview-customization-label]');
        if (label) {
          label.textContent = isPending ? copy.pending : copy[action];
        }

        const titleRow = wrapper.querySelector<HTMLElement>('[data-preview-title-row]');
        const existingPill = wrapper.querySelector<HTMLElement>('[data-preview-status-pill]');
        if (showRemovedTreatment) {
          if (existingPill) {
            existingPill.textContent = copy.removed;
          } else if (titleRow) {
            titleRow.insertAdjacentHTML(
              'beforeend',
              '<span data-preview-status-pill class="inline-flex items-center rounded-full border border-Border-border-danger bg-[rgba(255,64,64,0.08)] px-4 py-1 font-open-sans text-[14px] font-semibold leading-4 tracking-normal text-[#C91414] dark:bg-[rgba(255,64,64,0.16)] dark:text-[#FFB5B7]"></span>',
            );
            const insertedPill = titleRow.querySelector<HTMLElement>('[data-preview-status-pill]');
            if (insertedPill) {
              insertedPill.textContent = copy.removed;
            }
          }
        } else if (existingPill) {
          existingPill.remove();
        }
      });
    };

    const applyCustomizationReply = (
      target: PreviewCustomizationTarget,
      reply: PreviewCustomizationReply,
    ) => {
      clearPendingAnnouncement();
      const store = storeForPage(target.pageResourceId);
      store.applyReply(target, reply);
      const state = store.get(target);

      if (state) {
        updateFallbackPreviewCard(target, state);
      }
    };
    const recoverFromInvalidReply = (detail: {
      action: 'remove' | 'restore';
      target: PreviewCustomizationTarget;
    }) => {
      const failedReply = { ...detail, ok: false };
      applyCustomizationReply(detail.target, failedReply);
      window.dispatchEvent(
        new CustomEvent('oli:preview-customization:reply', {
          detail: failedReply,
        }),
      );
    };

    // Preview activities are custom elements hydrated by React, but the mutation authority stays
    // in LiveView. This hook is the bridge from browser-side preview actions back to the socket.
    this.handleEvent('preview_customization_reply', (reply) => {
      if (!isValidCustomizationReply(reply) || !reply.target) {
        return;
      }

      window.dispatchEvent(
        new CustomEvent('oli:preview-customization:reply', {
          detail: reply,
        }),
      );

      applyCustomizationReply(reply.target, reply);
    });

    this.handlePreviewCustomization = (event: Event) => {
      const detail = (event as CustomEvent).detail;

      if (!isValidCustomizationDetail(detail)) {
        return;
      }

      announcePendingUpdate();

      // The pushEvent callback carries the per-component reply while the same handle_event can
      // still update normal LiveView assigns for the rest of the page.
      this.pushEvent('toggle_preview_activity_customization', detail, (reply) => {
        if (!isValidCustomizationReply(reply)) {
          recoverFromInvalidReply(detail);
          return;
        }

        const mergedReply = {
          ...reply,
          ...detail,
        };
        applyCustomizationReply(detail.target, mergedReply);
        window.dispatchEvent(
          new CustomEvent('oli:preview-customization:reply', {
            detail: mergedReply,
          }),
        );
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

      let target: unknown;

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
      if (label) {
        label.textContent = copy.pending;
      }

      announcePendingUpdate();

      const store = storeForPage(detail.target.pageResourceId);
      store.initialize(detail.target, {
        disposition: detail.action === 'restore' ? 'removed' : 'included',
      });
      store.begin(detail.target, detail.action);

      this.pushEvent('toggle_preview_activity_customization', detail, (reply) => {
        if (!isValidCustomizationReply(reply)) {
          recoverFromInvalidReply(detail);
          return;
        }

        const mergedReply = { ...reply, ...detail };
        applyCustomizationReply(detail.target, mergedReply);

        window.dispatchEvent(
          new CustomEvent('oli:preview-customization:reply', {
            detail: mergedReply,
          }),
        );
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

    this.previewCustomizationPageIds?.forEach(clearFallbackPreviewCustomizationStore);
  },
};
