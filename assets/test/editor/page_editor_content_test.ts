import * as Immutable from 'immutable';
import PageEditor from 'apps/page-editor/PageEditor';
import { PageEditorContent, withDefaultContent } from 'data/editor/PageEditorContent';
import * as Bank from '../../src/data/content/bank';
import {
  ActivityBankSelection,
  PurposeGroupContent,
  ResourceContent,
} from '../../src/data/content/resource';

describe('PageEditorContent', () => {
  it('should be immutalble', () => {
    const content = new PageEditorContent({
      version: '1',
      model: withDefaultContent(Immutable.List()),
      trigger: undefined,
    });
    expect(() => (content.version = '2')).toThrow();
    const child: ActivityBankSelection = {
      type: 'selection',
      id: 'testChild',
      logic: {
        conditions: {
          fact: Bank.Fact.objectives,
          operator: Bank.ExpressionOperator.contains,
          value: [],
        },
      },
      count: 1,
      children: undefined,
    };
    expect(content.model.size).toEqual(1);
    const newContent1 = content.update('model', (model) => model.push(child));
    expect(content.model.size).toBe(1);
    expect(newContent1.model.size).toBe(2);

    const newContent2 = newContent1.updateAll((item: ResourceContent) => {
      if (item.type === 'selection') {
        return { ...item, count: 2 };
      }
      return item;
    });

    expect((newContent1.model.get(1) as ActivityBankSelection)?.count).toBe(1);
    expect((newContent2.model.get(1) as ActivityBankSelection)?.count).toBe(2);
  });

  it('should apply adjustContentForConstraints immutably', () => {
    const content = new PageEditorContent({
      version: '1',
      model: withDefaultContent(Immutable.List()),
      trigger: undefined,
    });
    expect(() => (content.version = '2')).toThrow();
    const child: ActivityBankSelection = {
      type: 'selection',
      id: 'testChild',
      logic: {
        conditions: {
          fact: Bank.Fact.objectives,
          operator: Bank.ExpressionOperator.contains,
          value: [],
        },
      },
      count: 1,
      children: undefined,
    };
    expect(content.model.size).toEqual(1);
    const newContent1 = content.update('model', (model) => model.push(child));
    expect(content.model.size).toBe(1);
    expect(newContent1.model.size).toBe(2);
    const newContent2 = PageEditor.adjustContentForConstraints(newContent1);

    expect((newContent1.model.get(1) as ActivityBankSelection)?.logic).toBe(child.logic);
    expect(child.logic).toEqual({
      conditions: {
        fact: Bank.Fact.objectives,
        operator: Bank.ExpressionOperator.contains,
        value: [],
      },
    });
    expect((newContent2.model.get(1) as ActivityBankSelection)?.logic).toEqual({
      conditions: null,
    });
  });

  it('should apply adjustContentForConstraints to groups immutably', () => {
    const content = new PageEditorContent({
      version: '1',
      model: withDefaultContent(Immutable.List()),
      trigger: undefined,
    });
    expect(() => (content.version = '2')).toThrow();

    const child: ActivityBankSelection = {
      type: 'selection',
      id: 'testChild',
      logic: {
        conditions: {
          fact: Bank.Fact.objectives,
          operator: Bank.ExpressionOperator.contains,
          value: [],
        },
      },
      count: 1,
      children: undefined,
    };

    const group: PurposeGroupContent = {
      type: 'group',
      id: 'g1',
      layout: 'vertical',
      purpose: 'instruction',
      children: Immutable.List([child]),
    };

    expect(content.model.size).toEqual(1);
    const newContent1 = content.update('model', (model) => model.push(group));
    expect(content.model.size).toBe(1);
    expect(newContent1.model.size).toBe(2);

    // At this point we have a PageEditorContent with a group inside it that has an activity bank selection inside the group

    // Sanity check to make sure the child is in the right place before we call adjustContentForConstraints
    expect((newContent1.model.get(1) as PurposeGroupContent)?.children.get(0)).toEqual(child);

    const newContent2 = PageEditor.adjustContentForConstraints(newContent1);

    // adjustContentForConstraints should not mutate it's input
    expect((newContent1.model.get(1) as PurposeGroupContent)?.children.get(0)).toEqual(child);

    // The original child should never be mutated
    expect(child.logic).toEqual({
      conditions: {
        fact: Bank.Fact.objectives,
        operator: Bank.ExpressionOperator.contains,
        value: [],
      },
    });

    // The new content should be modified by adjustContentForConstraints
    expect(
      ((newContent2.model.get(1) as PurposeGroupContent)?.children.get(0) as ActivityBankSelection)
        .logic,
    ).toEqual({
      conditions: null,
    });
  });
});
