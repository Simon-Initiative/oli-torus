import React from 'react';
import { act, render, screen } from '@testing-library/react';
import {
  ActivityBankSelectionPreview,
  ActivityBankSelectionPreviewPayload,
} from 'components/instructor_preview/activity_bank_selection_preview/ActivityBankSelectionPreview';

const removedSelection = (selectionId: string): ActivityBankSelectionPreviewPayload => ({
  id: selectionId,
  title: `Bank selection ${selectionId}`,
  selectedCount: 1,
  availableCount: 0,
  pointsPerActivity: 1,
  sampleActivity: null,
  canCustomize: true,
  actions: [{ kind: 'restore', label: 'Restore' }],
  visualState: 'removed',
  statusPill: { kind: 'removed', label: 'Removed' },
  customizationTarget: {
    kind: 'bank_selection',
    pageResourceId: 10,
    selectionId,
  },
});

const cardFor = (selectionId: string) =>
  screen.getByText(`Bank selection ${selectionId}`).closest('article') as HTMLElement;

describe('ActivityBankSelectionPreview', () => {
  test('restoring one selection removes only that card removed-state rail', () => {
    render(
      <>
        <ActivityBankSelectionPreview payload={removedSelection('first')} />
        <ActivityBankSelectionPreview payload={removedSelection('second')} />
        <ActivityBankSelectionPreview payload={removedSelection('last')} />
      </>,
    );

    expect(cardFor('first')).toHaveAttribute('data-preview-visual-state', 'removed');
    expect(cardFor('second')).toHaveAttribute('data-preview-visual-state', 'removed');
    expect(cardFor('last')).toHaveAttribute('data-preview-visual-state', 'removed');
    expect(cardFor('first').querySelector('[data-preview-removed-rail]')).toBeInTheDocument();
    expect(cardFor('second').querySelector('[data-preview-removed-rail]')).toBeInTheDocument();
    expect(cardFor('last').querySelector('[data-preview-removed-rail]')).toBeInTheDocument();

    act(() => {
      window.dispatchEvent(
        new CustomEvent('oli:preview-customization:reply', {
          detail: {
            ok: true,
            target: {
              kind: 'bank_selection',
              pageResourceId: 10,
              selectionId: 'last',
            },
            visualState: 'default',
            statusPill: null,
            actions: [{ kind: 'remove', label: 'Remove' }],
          },
        }),
      );
    });

    expect(cardFor('first').querySelector('[data-preview-removed-rail]')).toBeInTheDocument();
    expect(cardFor('second').querySelector('[data-preview-removed-rail]')).toBeInTheDocument();
    expect(cardFor('last').querySelector('[data-preview-removed-rail]')).not.toBeInTheDocument();
  });
});
