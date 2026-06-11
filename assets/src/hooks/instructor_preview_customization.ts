type InstructorPreviewCustomizationHook = {
  pushEvent: (
    event: string,
    payload: Record<string, unknown>,
    callback?: (reply: Record<string, unknown>) => void,
  ) => void;
  handlePreviewCustomization?: (event: Event) => void;
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
