import React from 'react';
import type { PreviewCustomizationTarget } from 'components/activities/types';

export type PreviewCustomizationDisposition = 'included' | 'removed';
export type PreviewCustomizationAction = 'remove' | 'restore';

export interface PreviewCustomizationCopy {
  remove: string;
  removed: string;
  restore: string;
  pending: string;
  pendingAnnouncement: string;
}

export interface PreviewCustomizationState {
  disposition: PreviewCustomizationDisposition;
  pendingAction: PreviewCustomizationAction | null;
  canToggle: boolean;
  availableCount?: number;
}

export interface PreviewCustomizationInitialState {
  disposition: PreviewCustomizationDisposition;
  canToggle?: boolean;
  availableCount?: number;
}

export interface PreviewCustomizationReply {
  ok?: boolean;
  target?: PreviewCustomizationTarget;
  disposition?: PreviewCustomizationDisposition;
  visualState?: 'default' | 'removed' | null;
  actions?: unknown;
  availableCount?: number;
}

type Listener = () => void;
type ServerStateChanges = Partial<PreviewCustomizationInitialState>;
type AuthoritativeReplyFields = Partial<Record<keyof PreviewCustomizationInitialState, boolean>>;

const pageStoreProperty = '__oliInstructorPreviewCustomizationStore';
const fallbackStoresProperty = '__oliInstructorPreviewCustomizationFallbackStores';
const copyAttribute = 'data-preview-customization-copy';

type PageStoreHost = HTMLElement & {
  [pageStoreProperty]?: PreviewCustomizationStore;
};

type GlobalWithFallbackStores = typeof globalThis & {
  [fallbackStoresProperty]?: Map<number, PreviewCustomizationStore>;
};

export const previewCustomizationTargetKey = (target: PreviewCustomizationTarget) =>
  [
    target.kind,
    target.pageResourceId,
    target.selectionId ?? '',
    target.activityResourceId ?? '',
  ].join(':');

export const getPreviewCustomizationCopy = (): PreviewCustomizationCopy => {
  const encodedCopy =
    typeof document === 'undefined'
      ? undefined
      : document.querySelector<HTMLElement>(`[${copyAttribute}]`)?.getAttribute(copyAttribute);

  if (!encodedCopy) {
    throw new Error('Instructor preview customization copy is missing from the page');
  }

  const copy = JSON.parse(encodedCopy) as Partial<PreviewCustomizationCopy>;

  if (
    typeof copy.remove !== 'string' ||
    typeof copy.removed !== 'string' ||
    typeof copy.restore !== 'string' ||
    typeof copy.pending !== 'string' ||
    typeof copy.pendingAnnouncement !== 'string'
  ) {
    throw new Error('Instructor preview customization copy is invalid');
  }

  return copy as PreviewCustomizationCopy;
};

export class PreviewCustomizationStore {
  readonly pageResourceId: number;

  private readonly entries = new Map<string, PreviewCustomizationState>();
  private readonly lastServerStates = new Map<string, PreviewCustomizationInitialState>();
  private readonly pendingServerChanges = new Map<string, ServerStateChanges>();
  private readonly listeners = new Map<string, Set<Listener>>();

  constructor(pageResourceId: number) {
    this.pageResourceId = pageResourceId;
  }

  initialize(
    target: PreviewCustomizationTarget,
    initialState: PreviewCustomizationInitialState,
  ): PreviewCustomizationState {
    const key = previewCustomizationTargetKey(target);
    const existing = this.entries.get(key);
    const normalizedInitialState = {
      ...initialState,
      canToggle: initialState.canToggle ?? true,
    };

    if (existing) {
      const previousInitialState = this.lastServerStates.get(key);

      if (!previousInitialState) {
        return existing;
      }

      const changes = serverStateChanges(previousInitialState, normalizedInitialState);
      // Reconcile only fields the server actually changed. An unchanged payload may be a stale
      // LiveView rerender and must not overwrite newer state applied from an action reply.
      this.lastServerStates.set(key, normalizedInitialState);

      if (existing.pendingAction) {
        this.pendingServerChanges.set(key, {
          ...this.pendingServerChanges.get(key),
          ...changes,
        });
        return existing;
      }

      const state = reconcileServerState(existing, changes);
      this.entries.set(key, state);
      return state;
    }

    const state = {
      ...normalizedInitialState,
      pendingAction: null,
    };
    this.lastServerStates.set(key, normalizedInitialState);
    this.entries.set(key, state);
    return state;
  }

  get(target: PreviewCustomizationTarget): PreviewCustomizationState | undefined {
    return this.entries.get(previewCustomizationTargetKey(target));
  }

  subscribe(target: PreviewCustomizationTarget, listener: Listener): () => void {
    const key = previewCustomizationTargetKey(target);
    const targetListeners = this.listeners.get(key) ?? new Set<Listener>();
    targetListeners.add(listener);
    this.listeners.set(key, targetListeners);

    return () => {
      targetListeners.delete(listener);

      if (targetListeners.size === 0) {
        this.listeners.delete(key);
      }
    };
  }

  begin(target: PreviewCustomizationTarget, action: PreviewCustomizationAction) {
    this.update(target, (state) => ({ ...state, pendingAction: action }));
  }

  applyReply(target: PreviewCustomizationTarget, reply: PreviewCustomizationReply) {
    const key = previewCustomizationTargetKey(target);
    const pendingServerChanges = this.pendingServerChanges.get(key);
    this.pendingServerChanges.delete(key);

    this.update(target, (state) => {
      if (!reply.ok) {
        return reconcileServerState({ ...state, pendingAction: null }, pendingServerChanges);
      }

      const replyAction = firstReplyAction(reply.actions);
      const dispositionFromAction =
        replyAction?.kind === 'restore'
          ? 'removed'
          : replyAction?.kind === 'remove'
          ? 'included'
          : undefined;
      const dispositionFromPendingAction =
        state.pendingAction === 'remove'
          ? 'removed'
          : state.pendingAction === 'restore'
          ? 'included'
          : undefined;
      const dispositionFromVisualState =
        reply.visualState === 'removed'
          ? 'removed'
          : reply.visualState === 'default'
          ? 'included'
          : undefined;
      const disposition =
        reply.disposition ??
        dispositionFromAction ??
        dispositionFromPendingAction ??
        dispositionFromVisualState ??
        state.disposition;

      const next = {
        ...state,
        disposition,
        pendingAction: null,
        canToggle:
          typeof replyAction?.disabled === 'boolean' ? !replyAction.disabled : state.canToggle,
        availableCount:
          typeof reply.availableCount === 'number' ? reply.availableCount : state.availableCount,
      };

      return reconcileServerState(next, pendingServerChanges, {
        disposition:
          reply.disposition !== undefined ||
          replyAction !== undefined ||
          state.pendingAction !== null ||
          reply.visualState === 'removed' ||
          reply.visualState === 'default',
        canToggle: typeof replyAction?.disabled === 'boolean',
        availableCount: typeof reply.availableCount === 'number',
      });
    });
  }

  private update(
    target: PreviewCustomizationTarget,
    updater: (state: PreviewCustomizationState) => PreviewCustomizationState,
  ) {
    const key = previewCustomizationTargetKey(target);
    const current = this.entries.get(key);

    if (!current) {
      return;
    }

    const next = updater(current);
    this.entries.set(key, next);
    this.listeners.get(key)?.forEach((listener) => listener());
  }
}

const serverStateChanges = (
  previous: PreviewCustomizationInitialState,
  next: PreviewCustomizationInitialState,
): ServerStateChanges => ({
  ...(next.disposition !== previous.disposition ? { disposition: next.disposition } : {}),
  ...(next.canToggle !== previous.canToggle ? { canToggle: next.canToggle } : {}),
  ...(next.availableCount !== previous.availableCount
    ? { availableCount: next.availableCount }
    : {}),
});

const reconcileServerState = (
  state: PreviewCustomizationState,
  changes?: ServerStateChanges,
  authoritativeReplyFields: AuthoritativeReplyFields = {},
): PreviewCustomizationState => {
  if (!changes) {
    return state;
  }

  return {
    ...state,
    disposition:
      !authoritativeReplyFields.disposition && changes.disposition !== undefined
        ? changes.disposition
        : state.disposition,
    canToggle:
      !authoritativeReplyFields.canToggle && changes.canToggle !== undefined
        ? changes.canToggle
        : state.canToggle,
    availableCount:
      !authoritativeReplyFields.availableCount && 'availableCount' in changes
        ? changes.availableCount
        : state.availableCount,
  };
};

const firstReplyAction = (
  actions: unknown,
): { kind: PreviewCustomizationAction; disabled?: boolean } | undefined => {
  if (!Array.isArray(actions)) {
    return undefined;
  }

  const action = actions[0];

  if (
    !action ||
    typeof action !== 'object' ||
    (action.kind !== 'remove' && action.kind !== 'restore')
  ) {
    return undefined;
  }

  return {
    kind: action.kind,
    disabled: typeof action.disabled === 'boolean' ? action.disabled : undefined,
  };
};

const pageStoreHost = (): PageStoreHost | null =>
  typeof document === 'undefined'
    ? null
    : (document.getElementById('instructor-preview-lesson') as PageStoreHost | null);

const fallbackStores = (): Map<number, PreviewCustomizationStore> => {
  const global = globalThis as GlobalWithFallbackStores;
  global[fallbackStoresProperty] ??= new Map<number, PreviewCustomizationStore>();
  return global[fallbackStoresProperty] as Map<number, PreviewCustomizationStore>;
};

export const getPreviewCustomizationStore = (pageResourceId: number) => {
  const host = pageStoreHost();

  if (host) {
    const existing = host[pageStoreProperty];

    if (existing?.pageResourceId === pageResourceId) {
      return existing;
    }

    const store = new PreviewCustomizationStore(pageResourceId);
    host[pageStoreProperty] = store;
    return store;
  }

  const stores = fallbackStores();
  const existing = stores.get(pageResourceId);

  if (existing) {
    return existing;
  }

  const store = new PreviewCustomizationStore(pageResourceId);
  stores.set(pageResourceId, store);
  return store;
};

export const clearPreviewCustomizationStore = (pageResourceId: number) => {
  const host = pageStoreHost();

  if (host?.[pageStoreProperty]?.pageResourceId === pageResourceId) {
    delete host[pageStoreProperty];
  }

  fallbackStores().delete(pageResourceId);
};

export const clearFallbackPreviewCustomizationStore = (pageResourceId: number) => {
  fallbackStores().delete(pageResourceId);
};

export const usePreviewCustomizationState = (
  target: PreviewCustomizationTarget,
  initialState: PreviewCustomizationInitialState,
) => {
  const store = getPreviewCustomizationStore(target.pageResourceId);
  const targetKey = previewCustomizationTargetKey(target);
  const [state, setState] = React.useState(() => store.initialize(target, initialState));

  React.useEffect(() => {
    const current = store.initialize(target, initialState);
    setState(current);

    return store.subscribe(target, () => {
      const next = store.get(target);

      if (next) {
        setState(next);
      }
    });
  }, [
    store,
    targetKey,
    initialState.disposition,
    initialState.canToggle,
    initialState.availableCount,
  ]);

  return {
    state,
    begin: (action: PreviewCustomizationAction) => store.begin(target, action),
  };
};
