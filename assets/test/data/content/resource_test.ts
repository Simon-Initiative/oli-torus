import * as Immutable from 'immutable';
import {
  ResourceContent,
  allElements,
  allowedContentItems,
  canInsert,
  createAlternative,
  createAlternatives,
  createDefaultLearningObjectivesContent,
  createDefaultStructuredContent,
  createGroup,
  createSurvey,
  getResourceContentName,
  isResourceContent,
  isResourceGroup,
} from 'data/content/resource';

describe('ResourceContent learning objectives element', () => {
  it('creates the default learning objectives content', () => {
    const content = createDefaultLearningObjectivesContent();

    expect(content).toMatchObject({
      type: 'learning_objectives',
      mode: 'introduction',
      include_sub_objectives: true,
      learning_objectives: [],
    });
    expect(content.id).toEqual(expect.any(String));
  });

  it('recognizes the learning objectives content type', () => {
    const content = createDefaultLearningObjectivesContent();

    expect(isResourceContent(content)).toBe(true);
    expect(getResourceContentName(content)).toBe('Learning Objectives');
    expect(allElements).toContain('learning_objectives');
  });

  it('keeps learning objectives out of resource groups', () => {
    const content = createDefaultLearningObjectivesContent();
    const group = createGroup();
    const survey = createSurvey();
    const alternative = createAlternative('A');
    const alternatives = createAlternatives(1, 'select_all', Immutable.List([alternative]));

    expect(isResourceGroup(content)).toBe(false);
    expect('children' in content).toBe(false);
    expect(allowedContentItems(group)).not.toContain('learning_objectives');
    expect(allowedContentItems(survey)).not.toContain('learning_objectives');
    expect(allowedContentItems(alternative)).not.toContain('learning_objectives');
    expect(allowedContentItems(alternatives)).not.toContain('learning_objectives');
  });

  it('allows learning objectives only at the root level', () => {
    const content = createDefaultLearningObjectivesContent();
    const group = createGroup();
    const structuredContent = createDefaultStructuredContent();

    expect(canInsert(content, [])).toBe(true);
    expect(canInsert(content, [group])).toBe(false);
    expect(canInsert(content, [group, structuredContent as ResourceContent])).toBe(false);
  });

  it('does not change existing root insertion support', () => {
    expect(canInsert(createDefaultStructuredContent(), [])).toBe(true);
    expect(canInsert(createGroup(), [])).toBe(true);
  });
});
