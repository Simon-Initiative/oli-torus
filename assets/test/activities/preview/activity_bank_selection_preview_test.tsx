import React from 'react';
import { act, fireEvent, render, screen } from '@testing-library/react';
import {
  ActivityBankSelectionPreview,
  ActivityBankSelectionPreviewPayload,
} from 'components/instructor_preview/activity_bank_selection_preview/ActivityBankSelectionPreview';
import 'components/instructor_preview/activity_bank_selection_preview/preview-entry';
import {
  clearPreviewCustomizationStore,
  getPreviewCustomizationStore,
} from 'components/instructor_preview/preview_customization_store';

const customizationCopy = {
  remove: 'Remove',
  removed: 'Removed',
  restore: 'Restore',
  pending: 'Updating...',
  pendingAnnouncement: 'Updating activity customization.',
};

const installCustomizationCopy = () => {
  const host = document.createElement('div');
  host.dataset.previewCustomizationCopy = JSON.stringify(customizationCopy);
  document.body.appendChild(host);
};

const includedSelection = (selectionId: string): ActivityBankSelectionPreviewPayload => ({
  id: selectionId,
  title: `Bank selection ${selectionId}`,
  selectedCount: 1,
  availableCount: 4,
  pointsPerActivity: 1,
  sampleActivity: null,
  canCustomize: true,
  actions: [{ kind: 'remove', label: 'Remove' }],
  visualState: 'default',
  statusPill: null,
  customizationTarget: {
    kind: 'bank_selection',
    pageResourceId: 10,
    selectionId,
  },
});

const cardFor = (selectionId: string) =>
  screen.getByText(`Bank selection ${selectionId}`).closest('article') as HTMLElement;

const dispatchReply = (selectionId: string, visualState: 'default' | 'removed') => {
  const removed = visualState === 'removed';

  act(() => {
    const target = {
      kind: 'bank_selection' as const,
      pageResourceId: 10,
      selectionId,
    };
    getPreviewCustomizationStore(10).applyReply(target, {
      ok: true,
      target,
      visualState,
      actions: [
        removed ? { kind: 'restore', label: 'Restore' } : { kind: 'remove', label: 'Remove' },
      ],
      availableCount: removed ? 0 : 4,
    });
  });
};

describe('ActivityBankSelectionPreview', () => {
  beforeEach(() => {
    clearPreviewCustomizationStore(10);
    installCustomizationCopy();
  });
  afterEach(() => {
    clearPreviewCustomizationStore(10);
    document
      .querySelectorAll('[data-preview-customization-copy]')
      .forEach((element) => element.remove());
  });

  test('uses the server-provided page copy for every action state', () => {
    const copyHost = document.querySelector<HTMLElement>('[data-preview-customization-copy]');
    copyHost!.dataset.previewCustomizationCopy = JSON.stringify({
      remove: 'Exclude question',
      removed: 'Excluded question',
      restore: 'Include question',
      pending: 'Saving...',
      pendingAnnouncement: 'Saving question customization.',
    });

    render(<ActivityBankSelectionPreview payload={includedSelection('first')} />);

    const target = includedSelection('first').customizationTarget;
    expect(screen.getByRole('button', { name: 'Exclude question' })).toBeInTheDocument();

    fireEvent.click(screen.getByRole('button', { name: 'Exclude question' }));
    expect(screen.getByRole('button', { name: 'Saving...' })).toBeInTheDocument();

    act(() => {
      getPreviewCustomizationStore(10).applyReply(target, {
        ok: true,
        target,
        visualState: 'removed',
        actions: [{ kind: 'restore', label: 'This payload label is not rendered' }],
      });
    });

    expect(screen.getByRole('button', { name: 'Include question' })).toBeInTheDocument();
    expect(screen.getByText('Excluded question')).toBeInTheDocument();
  });

  test('restoring one selection removes only that card removed-state rail', () => {
    const initialSelections = ['first', 'second', 'third'].map(includedSelection);
    const { rerender } = render(
      <>
        {initialSelections.map((selection) => (
          <ActivityBankSelectionPreview key={selection.id} payload={selection} />
        ))}
      </>,
    );

    dispatchReply('first', 'removed');
    dispatchReply('second', 'removed');
    dispatchReply('third', 'removed');

    expect(cardFor('first')).toHaveAttribute('data-preview-visual-state', 'removed');
    expect(cardFor('second')).toHaveAttribute('data-preview-visual-state', 'removed');
    expect(cardFor('third')).toHaveAttribute('data-preview-visual-state', 'removed');
    expect(cardFor('first').querySelector('[data-preview-removed-rail]')).toBeInTheDocument();
    expect(cardFor('second').querySelector('[data-preview-removed-rail]')).toBeInTheDocument();
    expect(cardFor('third').querySelector('[data-preview-removed-rail]')).toBeInTheDocument();

    rerender(
      <>
        {initialSelections.map((selection) => (
          <ActivityBankSelectionPreview
            key={selection.id}
            payload={{
              ...selection,
              customizationTarget: { ...selection.customizationTarget },
            }}
          />
        ))}
      </>,
    );

    expect(cardFor('first').querySelector('[data-preview-removed-rail]')).toBeInTheDocument();
    expect(cardFor('second').querySelector('[data-preview-removed-rail]')).toBeInTheDocument();
    expect(cardFor('third').querySelector('[data-preview-removed-rail]')).toBeInTheDocument();
    expect(cardFor('first').querySelector('button')).toHaveTextContent('Restore');
    expect(cardFor('second').querySelector('button')).toHaveTextContent('Restore');
    expect(cardFor('third').querySelector('button')).toHaveTextContent('Restore');

    dispatchReply('third', 'default');

    expect(cardFor('first').querySelector('[data-preview-removed-rail]')).toBeInTheDocument();
    expect(cardFor('second').querySelector('[data-preview-removed-rail]')).toBeInTheDocument();
    expect(cardFor('third').querySelector('[data-preview-removed-rail]')).not.toBeInTheDocument();
    expect(cardFor('first').querySelector('button')).toHaveTextContent('Restore');
    expect(cardFor('second').querySelector('button')).toHaveTextContent('Restore');
    expect(cardFor('third').querySelector('button')).toHaveTextContent('Remove');
  });

  test('preserves selection state through payload updates and transient reconnects', async () => {
    const hosts = ['first', 'second', 'third'].map((selectionId) => {
      const host = document.createElement('oli-activity-bank-selection-preview') as HTMLElement & {
        render: () => void;
      };

      host.setAttribute('payload', JSON.stringify(includedSelection(selectionId)));
      document.body.appendChild(host);

      return host;
    });

    dispatchReply('first', 'removed');
    dispatchReply('second', 'removed');
    dispatchReply('third', 'removed');

    hosts.forEach((host, index) => {
      const regeneratedPayload = {
        ...includedSelection(['first', 'second', 'third'][index]),
        selectedCount: 2,
      };

      host.setAttribute('payload', JSON.stringify(regeneratedPayload));
    });
    hosts.forEach((host) => {
      host.remove();
      document.body.appendChild(host);
    });
    hosts.forEach((host) => host.render());

    dispatchReply('third', 'default');

    expect(hosts[0].querySelector('[data-preview-removed-rail]')).toBeInTheDocument();
    expect(hosts[1].querySelector('[data-preview-removed-rail]')).toBeInTheDocument();
    expect(hosts[2].querySelector('[data-preview-removed-rail]')).not.toBeInTheDocument();
    expect(hosts[0].querySelector('button')).toHaveTextContent('Restore');
    expect(hosts[1].querySelector('button')).toHaveTextContent('Restore');
    expect(hosts[2].querySelector('button')).toHaveTextContent('Remove');
    hosts.forEach((host) => expect(host).toHaveTextContent('Selects: 2 questions'));

    hosts.forEach((host) => host.remove());
    await act(async () => Promise.resolve());
  });
});
