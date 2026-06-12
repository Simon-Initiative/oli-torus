import React from 'react';
import { act, fireEvent, render, screen } from '@testing-library/react';
import { PreviewElementProps } from 'components/activities/PreviewElement';
import {
  PreviewElementProvider,
  usePreviewElementContext,
} from 'components/activities/PreviewElementProvider';
import { ActivityPreviewCard } from 'components/activities/common/preview/ActivityPreviewCard';
import { ReadonlyPanel } from 'components/activities/common/preview/ReadonlyPanel';
import { ActivityModelSchema, PreviewContext } from 'components/activities/types';
import { InstructorPreviewCustomization } from 'hooks/instructor_preview_customization';

const previewContext: PreviewContext = {
  sectionSlug: 'section-1',
  pageResourceId: 10,
  pageRevisionSlug: 'page-1',
  activityResourceId: 100,
  activityHtmlId: 'activity_100',
  activityId: 100,
  activityTypeSlug: 'oli_multiple_choice',
  activityTypeLabel: 'Multiple Choice',
  title: 'Identify the best answer',
  points: 3,
  learningObjectives: ['Explain entropy', 'Interpret Gibbs free energy'],
  canCustomize: true,
  customizationTarget: {
    kind: 'embedded_activity',
    pageResourceId: 10,
    activityResourceId: 100,
  },
  bibParams: { encoded: 'YmlibGlvZ3JhcGh5' },
  variables: {},
};

describe('ActivityPreviewCard', () => {
  test('toggles details and switches tabs with keyboard navigation', () => {
    render(
      <ActivityPreviewCard
        previewContext={previewContext}
        detailTabs={[
          {
            id: 'answer-key',
            label: 'Answer Key',
            content: <ReadonlyPanel title="Answer Key">Correct answer content</ReadonlyPanel>,
          },
          {
            id: 'hints',
            label: 'Hints',
            content: <ReadonlyPanel title="Hints">Hint content</ReadonlyPanel>,
          },
        ]}
      >
        <div>Question body</div>
      </ActivityPreviewCard>,
    );

    expect(screen.getByText('Multiple Choice')).toBeInTheDocument();
    expect(screen.getByText('Identify the best answer')).toBeInTheDocument();
    expect(screen.getByText('3 points')).toBeInTheDocument();
    expect(screen.getByText('Explain entropy')).toBeInTheDocument();
    expect(screen.queryByText('Correct answer content')).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole('button', { name: /view details/i }));

    expect(screen.getByText('Correct answer content')).toBeInTheDocument();

    const answerKeyTab = screen.getByRole('tab', { name: 'Answer Key' });
    fireEvent.keyDown(answerKeyTab, { key: 'ArrowRight' });

    expect(screen.getByRole('tab', { name: 'Hints' })).toHaveFocus();
    expect(screen.getByText('Hint content')).toBeInTheDocument();
    expect(answerKeyTab).toHaveAttribute('id', 'activity_100-preview-tab-answer-key');
    expect(answerKeyTab).toHaveAttribute('aria-controls', 'activity_100-preview-panel-answer-key');
    expect(screen.getByRole('tabpanel')).toHaveAttribute('id', 'activity_100-preview-panel-hints');
  });

  test('renders learning objectives as a vertical list and hides the section when empty', () => {
    const { rerender } = render(
      <ActivityPreviewCard previewContext={previewContext}>
        <div>Question body</div>
      </ActivityPreviewCard>,
    );

    expect(screen.getByRole('list', { name: 'Learning objectives' })).toBeInTheDocument();
    expect(screen.getAllByRole('listitem')).toHaveLength(2);
    expect(screen.getAllByText('LO')).toHaveLength(2);
    expect(screen.getByText('Explain entropy')).toBeInTheDocument();
    expect(screen.getByText('Interpret Gibbs free energy')).toBeInTheDocument();
    expect(screen.getAllByText('Learning objective', { selector: '.sr-only' })).toHaveLength(2);

    const noObjectiveContext = { ...previewContext, learningObjectives: [] };

    rerender(
      <ActivityPreviewCard previewContext={noObjectiveContext}>
        <div>Question body</div>
      </ActivityPreviewCard>,
    );

    expect(screen.queryByText('LO')).not.toBeInTheDocument();
    expect(screen.queryByText('Explain entropy')).not.toBeInTheDocument();
    expect(screen.queryByText('Interpret Gibbs free energy')).not.toBeInTheDocument();
  });

  test('updates action label from remove to restore after LiveView reply without remounting', () => {
    const actionableContext = {
      ...previewContext,
      actions: [{ kind: 'remove' as const, label: 'Remove' }],
    };

    render(
      <ActivityPreviewCard previewContext={actionableContext}>
        <div>Question body</div>
      </ActivityPreviewCard>,
    );

    fireEvent.click(screen.getByRole('button', { name: 'Remove' }));

    expect(screen.getByRole('button', { name: 'Updating...' })).toBeInTheDocument();

    act(() => {
      window.dispatchEvent(
        new CustomEvent('oli:preview-customization:reply', {
          detail: {
            ok: true,
            target: {
              kind: 'embedded_activity',
              pageResourceId: 10,
              activityResourceId: 100,
            },
            activityResourceId: 100,
            visualState: 'removed',
            statusPill: { kind: 'removed', label: 'Removed' },
            actions: [{ kind: 'restore', label: 'Restore' }],
          },
        }),
      );
    });

    expect(screen.getByRole('button', { name: 'Restore' })).toBeInTheDocument();
    expect(screen.getByText('Removed')).toBeInTheDocument();
  });

  test('matches replies for selection-based targets using the full customization target', () => {
    const selectionContext = {
      ...previewContext,
      actions: [{ kind: 'remove' as const, label: 'Remove bank' }],
      customizationTarget: {
        kind: 'bank_selection' as const,
        pageResourceId: 10,
        selectionId: 'selection-1',
      },
    };

    render(
      <ActivityPreviewCard previewContext={selectionContext}>
        <div>Question body</div>
      </ActivityPreviewCard>,
    );

    fireEvent.click(screen.getByRole('button', { name: 'Remove bank' }));

    act(() => {
      window.dispatchEvent(
        new CustomEvent('oli:preview-customization:reply', {
          detail: {
            ok: true,
            target: {
              kind: 'bank_selection',
              pageResourceId: 10,
              selectionId: 'selection-1',
            },
            actions: [{ kind: 'restore', label: 'Restore' }],
          },
        }),
      );
    });

    expect(screen.getByRole('button', { name: 'Restore' })).toBeInTheDocument();
  });

  test('renders removed visual treatment only when the preview context asks for it', () => {
    const removedContext = {
      ...previewContext,
      actions: [{ kind: 'restore' as const, label: 'Restore' }],
      visualState: 'removed' as const,
      statusPill: { kind: 'removed' as const, label: 'Removed' },
    };

    const { rerender } = render(
      <ActivityPreviewCard previewContext={removedContext}>
        <div>Question body</div>
      </ActivityPreviewCard>,
    );

    expect(screen.getByText('Removed')).toBeInTheDocument();
    expect(screen.getByText('Question body').closest('article')).toHaveClass(
      'relative',
      'before:w-[6px]',
      'before:bg-Border-border-danger',
    );

    const restoreOnlyContext = {
      ...previewContext,
      actions: [{ kind: 'restore' as const, label: 'Restore' }],
    };

    rerender(
      <ActivityPreviewCard previewContext={restoreOnlyContext}>
        <div>Question body</div>
      </ActivityPreviewCard>,
    );

    expect(screen.queryByText('Removed')).not.toBeInTheDocument();
    expect(screen.getByText('Question body').closest('article')).not.toHaveClass('border-l-4');
  });
});

const Consumer: React.FC = () => {
  const { writerContext, previewContext } = usePreviewElementContext<ActivityModelSchema>();

  return (
    <>
      <div>{writerContext.sectionSlug}</div>
      <div>{String(writerContext.resourceId)}</div>
      <div>{previewContext.title}</div>
    </>
  );
};

describe('PreviewElementProvider', () => {
  test('provides preview context and derived writer context', () => {
    const props: PreviewElementProps<ActivityModelSchema> = {
      model: {},
      previewContext,
      mode: 'preview',
    };

    render(
      <PreviewElementProvider {...props}>
        <Consumer />
      </PreviewElementProvider>,
    );

    expect(screen.getByText('section-1')).toBeInTheDocument();
    expect(screen.getByText('10')).toBeInTheDocument();
    expect(screen.getByText('Identify the best answer')).toBeInTheDocument();
  });
});

describe('InstructorPreviewCustomization fallback preview wiring', () => {
  test('updates a server-rendered authoring fallback card after a successful reply', () => {
    document.body.innerHTML = `
      <div class="instructor-preview-activity-wrapper instructor-preview-authoring-fallback instructor-preview-default mb-6 rounded-lg border border-Border-border-default overflow-hidden p-6 bg-Surface-surface-primary">
        <header class="mb-4 flex flex-col gap-3">
          <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between sm:gap-4">
            <div class="flex min-w-0 flex-col gap-2">
              <div class="flex flex-wrap items-center gap-3 text-sm font-normal leading-[21px] text-Text-text-low-alpha">
                <span>Short Answer</span>
              </div>
              <div data-preview-title-row="200" class="flex flex-wrap items-center gap-3">
                <h3 class="!m-0 text-xl font-semibold leading-[26px] text-Text-text-high">Fallback Activity</h3>
              </div>
            </div>
            <div class="w-full sm:w-auto sm:shrink-0">
              <div data-preview-action-container="200" class="flex flex-wrap items-center gap-2">
                <button
                  type="button"
                  data-preview-customization-action="remove"
                  data-preview-customization-target='{"kind":"embedded_activity","pageResourceId":10,"activityResourceId":200}'
                  data-preview-customization-button
                  class="initial-button-class"
                >
                  <span data-preview-customization-label>Remove</span>
                </button>
              </div>
            </div>
          </div>
        </header>
      </div>
    `;

    const pushEvent = jest.fn(
      (
        _event: string,
        _payload: Record<string, unknown>,
        callback?: (reply: Record<string, unknown>) => void,
      ) => {
        callback?.({
          ok: true,
          actions: [{ kind: 'restore', label: 'Restore' }],
          visualState: 'removed',
          statusPill: { kind: 'removed', label: 'Removed' },
        });
      },
    );

    const hook: {
      pushEvent: (
        event: string,
        payload: Record<string, unknown>,
        callback?: (reply: Record<string, unknown>) => void,
      ) => void;
      handlePreviewCustomization?: (event: Event) => void;
      handleFallbackPreviewCustomizationClick?: (event: Event) => void;
    } = {
      pushEvent,
    };

    InstructorPreviewCustomization.mounted.call(hook);

    fireEvent.click(screen.getByRole('button', { name: 'Remove' }));

    expect(pushEvent).toHaveBeenCalledWith(
      'toggle_preview_activity_customization',
      {
        action: 'remove',
        target: {
          kind: 'embedded_activity',
          pageResourceId: 10,
          activityResourceId: 200,
        },
      },
      expect.any(Function),
    );

    expect(screen.getByRole('button', { name: 'Restore' })).toBeInTheDocument();
    expect(screen.getByText('Removed')).toBeInTheDocument();
    expect(document.querySelector('.instructor-preview-activity-wrapper')).toHaveClass(
      'instructor-preview-authoring-fallback',
      'instructor-preview-removed',
      'bg-Surface-surface-secondary-muted',
      'before:w-[6px]',
      'before:bg-Border-border-danger',
    );

    InstructorPreviewCustomization.destroyed.call(hook);
    document.body.innerHTML = '';
  });
});
