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
import {
  clearPreviewCustomizationStore,
  getPreviewCustomizationStore,
} from 'components/instructor_preview/preview_customization_store';
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
  beforeEach(() => clearPreviewCustomizationStore(10));
  afterEach(() => clearPreviewCustomizationStore(10));

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
      const target = {
        kind: 'embedded_activity' as const,
        pageResourceId: 10,
        activityResourceId: 100,
      };
      getPreviewCustomizationStore(10).applyReply(target, {
        ok: true,
        target,
        visualState: 'removed',
        actions: [{ kind: 'restore', label: 'Restore' }],
      });
    });

    expect(screen.getByRole('button', { name: 'Restore' })).toBeInTheDocument();
    expect(screen.getByText('Removed')).toBeInTheDocument();
  });

  test('preserves each embedded activity removal through stale preview-context rerenders', () => {
    const includedContext = (activityResourceId: number): PreviewContext => ({
      ...previewContext,
      activityResourceId,
      activityHtmlId: `activity_${activityResourceId}`,
      title: `Activity ${activityResourceId}`,
      actions: [{ kind: 'remove', label: 'Remove' }],
      visualState: 'default',
      customizationTarget: {
        kind: 'embedded_activity',
        pageResourceId: 10,
        activityResourceId,
      },
    });
    const initialContexts = [includedContext(100), includedContext(200)];
    const { rerender } = render(
      <>
        {initialContexts.map((context) => (
          <ActivityPreviewCard key={context.activityResourceId} previewContext={context}>
            <div>{`Question ${context.activityResourceId}`}</div>
          </ActivityPreviewCard>
        ))}
      </>,
    );

    [100, 200].forEach((activityResourceId) => {
      act(() => {
        const target = {
          kind: 'embedded_activity' as const,
          pageResourceId: 10,
          activityResourceId,
        };
        getPreviewCustomizationStore(10).applyReply(target, {
          ok: true,
          target,
          visualState: 'removed',
          actions: [{ kind: 'restore', label: 'Restore' }],
        });
      });
    });

    rerender(
      <>
        {initialContexts.map((context) => (
          <ActivityPreviewCard
            key={context.activityResourceId}
            previewContext={{
              ...context,
              actions: [{ kind: 'remove', label: 'Remove' }],
              customizationTarget: { ...context.customizationTarget },
            }}
          >
            <div>{`Question ${context.activityResourceId}`}</div>
          </ActivityPreviewCard>
        ))}
      </>,
    );

    act(() => {
      const target = {
        kind: 'embedded_activity' as const,
        pageResourceId: 10,
        activityResourceId: 200,
      };
      getPreviewCustomizationStore(10).applyReply(target, {
        ok: true,
        target,
        visualState: 'default',
        actions: [{ kind: 'remove', label: 'Remove' }],
      });
    });

    const firstCard = screen.getByText('Question 100').closest('article') as HTMLElement;
    const secondCard = screen.getByText('Question 200').closest('article') as HTMLElement;

    expect(firstCard).toHaveClass('before:bg-Border-border-danger');
    expect(firstCard).toHaveTextContent('Restore');
    expect(secondCard).not.toHaveClass('before:bg-Border-border-danger');
    expect(secondCard).toHaveTextContent('Remove');
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

    fireEvent.click(screen.getByRole('button', { name: 'Remove' }));

    act(() => {
      const target = {
        kind: 'bank_selection' as const,
        pageResourceId: 10,
        selectionId: 'selection-1',
      };
      getPreviewCustomizationStore(10).applyReply(target, {
        ok: true,
        target,
        visualState: 'removed',
        actions: [{ kind: 'restore', label: 'Restore' }],
      });
    });

    expect(screen.getByRole('button', { name: 'Restore' })).toBeInTheDocument();
  });

  test('tracks bank-candidate disposition without applying removed-card treatment', () => {
    const candidateTarget = {
      kind: 'bank_candidate' as const,
      pageResourceId: 10,
      selectionId: 'selection-1',
      activityResourceId: 100,
    };
    const candidateContext = {
      ...previewContext,
      actions: [{ kind: 'remove' as const, label: 'Remove' }],
      customizationTarget: candidateTarget,
    };

    render(
      <ActivityPreviewCard previewContext={candidateContext}>
        <div>Candidate question</div>
      </ActivityPreviewCard>,
    );

    act(() => {
      getPreviewCustomizationStore(10).applyReply(candidateTarget, {
        ok: true,
        target: candidateTarget,
        visualState: 'default',
        actions: [{ kind: 'restore', label: 'Restore' }],
      });
    });

    const card = screen.getByText('Candidate question').closest('article') as HTMLElement;
    expect(screen.getByRole('button', { name: 'Restore' })).toBeInTheDocument();
    expect(card).not.toHaveClass('before:bg-Border-border-danger');
    expect(screen.queryByText('Removed')).not.toBeInTheDocument();

    act(() => {
      getPreviewCustomizationStore(10).applyReply(candidateTarget, {
        ok: true,
        target: candidateTarget,
        actions: [{ kind: 'restore', label: 'Restore', disabled: true }],
      });
    });

    expect(screen.getByRole('button', { name: 'Restore' })).toBeDisabled();
  });

  test('derives removed visual treatment from semantic customization state', () => {
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

    act(() => {
      getPreviewCustomizationStore(10).applyReply(previewContext.customizationTarget, {
        ok: true,
        target: previewContext.customizationTarget,
        disposition: 'included',
      });
    });

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
      handleEvent: (event: string, callback: (payload: Record<string, unknown>) => void) => void;
      handlePreviewCustomization?: (event: Event) => void;
      handleFallbackPreviewCustomizationClick?: (event: Event) => void;
    } = {
      pushEvent,
      handleEvent: jest.fn(),
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

  test('keeps removed bank-candidate fallbacks visually default and labels bulk-disabled actions', () => {
    document.body.innerHTML = `
      <div class="instructor-preview-activity-wrapper instructor-preview-authoring-fallback instructor-preview-default">
        <div data-preview-title-row="200"><h3>Fallback Candidate</h3></div>
        <button
          type="button"
          data-preview-customization-action="remove"
          data-preview-customization-target='{"kind":"bank_candidate","pageResourceId":10,"selectionId":"selection-1","activityResourceId":200}'
          data-preview-customization-button
        >
          <span data-preview-customization-label>Remove</span>
        </button>
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
          visualState: 'default',
          actions: [{ kind: 'restore', label: 'Restore' }],
        });
      },
    );
    const handleEvent = jest.fn();
    const hook = {
      pushEvent,
      handleEvent,
      handlePreviewCustomization: undefined as ((event: Event) => void) | undefined,
      handleFallbackPreviewCustomizationClick: undefined as ((event: Event) => void) | undefined,
    };

    InstructorPreviewCustomization.mounted.call(hook);
    fireEvent.click(screen.getByRole('button', { name: 'Remove' }));

    const wrapper = document.querySelector('.instructor-preview-activity-wrapper');
    expect(screen.getByRole('button', { name: 'Restore' })).toBeInTheDocument();
    expect(wrapper).toHaveClass('instructor-preview-default');
    expect(wrapper).not.toHaveClass('instructor-preview-removed', 'before:bg-Border-border-danger');
    expect(screen.queryByText('Removed')).not.toBeInTheDocument();

    const serverReply = handleEvent.mock.calls[0][1] as (reply: Record<string, unknown>) => void;
    act(() => {
      serverReply({
        ok: true,
        target: {
          kind: 'bank_candidate',
          pageResourceId: 10,
          selectionId: 'selection-1',
          activityResourceId: 200,
        },
        actions: [{ kind: 'restore', label: 'Restore', disabled: true }],
      });
    });

    expect(screen.getByRole('button', { name: 'Restore' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Restore' })).toHaveAttribute('aria-busy', 'false');

    InstructorPreviewCustomization.destroyed.call(hook);
    document.body.innerHTML = '';
  });
});
