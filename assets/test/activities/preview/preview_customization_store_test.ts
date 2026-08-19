import type { PreviewCustomizationTarget } from 'components/activities/types';
import { PreviewCustomizationStore } from 'components/instructor_preview/preview_customization_store';

const target: PreviewCustomizationTarget = {
  kind: 'bank_selection',
  pageResourceId: 10,
  selectionId: 'selection-1',
};

describe('PreviewCustomizationStore', () => {
  test('reconciles changed server state without overwriting reply state with stale inputs', () => {
    const store = new PreviewCustomizationStore(10);
    const includedState = {
      disposition: 'included' as const,
      canToggle: true,
      availableCount: 4,
    };

    store.initialize(target, includedState);
    store.applyReply(target, {
      ok: true,
      visualState: 'removed',
      availableCount: 3,
    });

    expect(store.initialize(target, includedState)).toMatchObject({
      disposition: 'removed',
      canToggle: true,
      availableCount: 3,
    });

    expect(
      store.initialize(target, {
        disposition: 'removed',
        canToggle: false,
        availableCount: 2,
      }),
    ).toMatchObject({
      disposition: 'removed',
      canToggle: false,
      availableCount: 2,
    });

    expect(
      store.initialize(target, {
        disposition: 'included',
        canToggle: true,
        availableCount: 4,
      }),
    ).toMatchObject({
      disposition: 'included',
      canToggle: true,
      availableCount: 4,
    });
  });

  test('maps an explicit default visual state to included', () => {
    const store = new PreviewCustomizationStore(10);

    store.initialize(target, { disposition: 'removed' });
    store.applyReply(target, { ok: true, visualState: 'default' });

    expect(store.get(target)?.disposition).toBe('included');
  });

  test('reconciles server updates received while an action is pending', () => {
    const store = new PreviewCustomizationStore(10);

    store.initialize(target, {
      disposition: 'included',
      canToggle: true,
      availableCount: 4,
    });
    store.begin(target, 'remove');

    store.initialize(target, {
      disposition: 'included',
      canToggle: false,
      availableCount: 2,
    });
    store.applyReply(target, { ok: true, visualState: 'removed' });

    expect(store.get(target)).toMatchObject({
      disposition: 'removed',
      pendingAction: null,
      canToggle: false,
      availableCount: 2,
    });
  });

  test('prefers authoritative reply fields over queued server updates', () => {
    const store = new PreviewCustomizationStore(10);

    store.initialize(target, {
      disposition: 'included',
      canToggle: true,
      availableCount: 4,
    });
    store.begin(target, 'remove');

    store.initialize(target, {
      disposition: 'included',
      canToggle: false,
      availableCount: 2,
    });
    store.applyReply(target, {
      ok: true,
      visualState: 'removed',
      actions: [{ kind: 'restore', disabled: false }],
      availableCount: 3,
    });

    expect(store.get(target)).toMatchObject({
      disposition: 'removed',
      pendingAction: null,
      canToggle: true,
      availableCount: 3,
    });
  });
});
