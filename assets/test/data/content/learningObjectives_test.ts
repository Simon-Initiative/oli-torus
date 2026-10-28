import * as Immutable from 'immutable';
import {
  reconcileLearningObjectivesContent,
  reconcileLearningObjectivesInPageContent,
} from 'data/content/learningObjectives';
import {
  ActivityReference,
  LearningObjectivesContent,
  ResolvedLearningObjective,
  ResourceContent,
  createDefaultStructuredContent,
} from 'data/content/resource';
import { PageEditorContent } from 'data/editor/PageEditorContent';

const resolved = (resource_id: number): ResolvedLearningObjective => ({
  resource_id,
  title: `Objective ${resource_id}`,
  description: null,
  parent_resource_id: null,
  children: [],
  related_activity_ids: [],
  directly_matched: true,
});

const element = (
  learning_objectives: LearningObjectivesContent['learning_objectives'],
): LearningObjectivesContent => ({
  type: 'learning_objectives',
  id: 'lo-element',
  mode: 'summary',
  include_sub_objectives: true,
  learning_objectives,
});

describe('Learning Objectives page-load reconciliation', () => {
  it('preserves present objective config, adds newly found objectives, and removes stale rows', () => {
    const existing = element([
      { resource_id: 2, enabled: false, revisit_pages: [10], practice_pages: [20, 21] },
      { resource_id: 99, enabled: true, revisit_pages: [11], practice_pages: [] },
    ]);

    const result = reconcileLearningObjectivesContent(existing, [resolved(2), resolved(3)]);

    expect(result.changed).toEqual(true);
    expect(result.content.learning_objectives).toEqual([
      { resource_id: 2, enabled: false, revisit_pages: [10], practice_pages: [20, 21] },
      { resource_id: 3, enabled: true, revisit_pages: [], practice_pages: [] },
    ]);
  });

  it('does not report a change when advisory rows already match the resolved objective set', () => {
    const existing = element([
      { resource_id: 1, enabled: true, revisit_pages: [], practice_pages: [] },
      { resource_id: 2, enabled: false, revisit_pages: [10], practice_pages: [20] },
    ]);

    const result = reconcileLearningObjectivesContent(existing, [resolved(1), resolved(2)]);

    expect(result.changed).toEqual(false);
    expect(result.content).toBe(existing);
  });

  it('returns the original page content when the page has no Learning Objectives element', () => {
    const content = new PageEditorContent({
      version: '0.1.0',
      model: Immutable.List<ResourceContent>([createDefaultStructuredContent()]),
      trigger: undefined,
    });

    const result = reconcileLearningObjectivesInPageContent(content, [resolved(1)]);

    expect(result.changed).toEqual(false);
    expect(result.content).toBe(content);
  });

  it('does not reconcile when the resolved objective payload is unavailable', () => {
    const loElement = element([
      { resource_id: 1, enabled: false, revisit_pages: [100], practice_pages: [101] },
    ]);
    const content = new PageEditorContent({
      version: '0.1.0',
      model: Immutable.List<ResourceContent>([loElement]),
      trigger: undefined,
    });

    const result = reconcileLearningObjectivesInPageContent(content, undefined);

    expect(result.changed).toEqual(false);
    expect(result.content).toBe(content);
    expect(result.content.find(loElement.id)).toBe(loElement);
  });

  it('does not mutate unrelated page content or activity objective tags', () => {
    const activity: ActivityReference = {
      type: 'activity-reference',
      id: 'activity-ref',
      activitySlug: 'activity-slug',
      children: [],
    };
    const text = createDefaultStructuredContent();
    const loElement = element([
      { resource_id: 1, enabled: true, revisit_pages: [100], practice_pages: [101] },
    ]);
    const content = new PageEditorContent({
      version: '0.1.0',
      model: Immutable.List<ResourceContent>([text, loElement, activity]),
      trigger: undefined,
    });

    const result = reconcileLearningObjectivesInPageContent(content, [resolved(1), resolved(2)]);

    expect(result.changed).toEqual(true);
    expect(result.content.find(text.id)).toBe(text);
    expect(result.content.find(activity.id)).toBe(activity);
    expect(result.content.find(activity.id)).toEqual(activity);
    expect(
      (result.content.find(loElement.id) as LearningObjectivesContent).learning_objectives,
    ).toEqual([
      { resource_id: 1, enabled: true, revisit_pages: [100], practice_pages: [101] },
      { resource_id: 2, enabled: true, revisit_pages: [], practice_pages: [] },
    ]);
  });
});
