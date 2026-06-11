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
