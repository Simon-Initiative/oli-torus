import React from 'react';
import '@testing-library/jest-dom';
import { fireEvent, render, screen, within } from '@testing-library/react';
import * as Immutable from 'immutable';
import {
  AlternativesGroupBlock,
  EmptyOptionsNotice,
  StaleOptionNotice,
  reconcileAlternativeOptions,
  updateAlternativeContent,
} from 'components/resource/editors/AlternativesEditor';
import {
  AlternativeContent,
  ResourceContent,
  createAlternative,
  createAlternatives,
} from 'data/content/resource';

const option = (id: string, value: string): AlternativeContent => ({
  ...createAlternative(value, Immutable.List()),
  id,
});

describe('page-editor alternatives tabs', () => {
  it('shows every current option in managed order while preserving content by stable option ID', () => {
    const beta = option('beta-content', 'beta-id');
    const removed = option('removed-content', 'removed-id');
    const children = Immutable.List([removed, beta]);

    const reconciled = reconcileAlternativeOptions(children, [
      { id: 'alpha-id', name: 'Alpha' },
      { id: 'beta-id', name: 'Beta renamed' },
    ]);

    expect(reconciled.map((child) => child.value).toArray()).toEqual([
      'alpha-id',
      'beta-id',
      'removed-id',
    ]);
    expect(reconciled.get(1)).toBe(beta);
    expect(reconciled.get(2)).toBe(removed);
  });

  it('supports tab selection and content rendering without option-management actions', () => {
    const alpha = option('alpha-content', 'alpha-id');
    const beta = option('beta-content', 'beta-id');
    const setActiveOption = jest.fn();
    const contentItem = createAlternatives(
      42,
      'user_section_preference',
      Immutable.List([alpha, beta]),
    );
    render(
      <AlternativesGroupBlock
        editMode
        contentItem={contentItem}
        groupTitle="Learner Path"
        activeOption={alpha}
        parents={[]}
        canRemove={false}
        alternativeOptionsTitles={{ 'alpha-id': 'Alpha', 'beta-id': 'Beta' }}
        onRemove={jest.fn()}
        setActiveOption={setActiveOption}
      >
        <div>Branch content editor</div>
      </AlternativesGroupBlock>,
    );

    expect(screen.getByText('Branch content editor')).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: 'Learner Path' })).toBeInTheDocument();
    const tablist = screen.getByRole('tablist', { name: 'Alternative content options' });
    const tabs = within(tablist).getAllByRole('tab');
    expect(tabs).toHaveLength(2);
    expect(tabs[0]).toHaveAccessibleName('Alpha');
    expect(tabs[0]).toHaveAttribute('aria-selected', 'true');
    expect(within(tablist).queryAllByRole('button')).toHaveLength(0);

    fireEvent.keyDown(tabs[0], { key: 'ArrowRight' });
    expect(setActiveOption).toHaveBeenCalledWith(beta);
    expect(tabs[1]).toHaveFocus();
  });

  it('shows the decision point name instead of a generic A/B heading', () => {
    const alpha = option('alpha-content', 'alpha-id');
    const contentItem = createAlternatives(42, 'upgrade_decision_point', Immutable.List([alpha]));

    render(
      <AlternativesGroupBlock
        editMode
        contentItem={contentItem}
        groupTitle="Homepage Recommendation"
        activeOption={alpha}
        parents={[]}
        canRemove={false}
        alternativeOptionsTitles={{ 'alpha-id': 'Alpha' }}
        onRemove={jest.fn()}
        setActiveOption={jest.fn()}
      >
        <div>Branch content editor</div>
      </AlternativesGroupBlock>,
    );

    expect(screen.getByRole('heading', { name: 'Homepage Recommendation' })).toBeInTheDocument();
    expect(screen.queryByText('A/B Testing Decision Point')).not.toBeInTheDocument();
  });

  it('writes branch-content edits back to the matching stable option branch only', () => {
    const alpha = option('alpha-content', 'alpha-id');
    const beta = option('beta-content', 'beta-id');
    const contentItem = createAlternatives(
      42,
      'user_section_preference',
      Immutable.List([alpha, beta]),
    );
    const editedAlpha = { ...alpha, children: Immutable.List<ResourceContent>() };

    const updated = updateAlternativeContent(contentItem, editedAlpha);

    expect(updated.children.get(0)).toBe(editedAlpha);
    expect(updated.children.get(0)?.value).toBe('alpha-id');
    expect(updated.children.get(1)).toBe(beta);
  });

  it('provides an actionable warning without reassigning stale content', () => {
    render(<StaleOptionNotice projectSlug="example-project" />);

    expect(
      screen.getByText(/content belongs to an option that no longer exists/i),
    ).toBeInTheDocument();
    expect(
      screen.getByRole('link', { name: /review options in manage alternatives/i }),
    ).toHaveAttribute('href', '/workspaces/course_author/example-project/alternatives');
  });

  it('links the empty state to Manage Alternatives', () => {
    render(<EmptyOptionsNotice projectSlug="example-project" />);

    expect(
      screen.getByRole('link', { name: /add options in manage alternatives/i }),
    ).toHaveAttribute('href', '/workspaces/course_author/example-project/alternatives');
  });
});
