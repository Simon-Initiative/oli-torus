import {
  deleteConditionById,
  findConditionById,
  forEachCondition,
} from 'apps/authoring/components/AdaptivityEditor/ConditionsBlockEditor';
import { mockDefaultRule, mockRuleNestedConditions, mockRuleWithConditions1 } from './rule_mocks';

describe('Rule Editor', () => {
  describe('findConditionById', () => {
    it('should find the condition by id', () => {
      const condition = findConditionById('c:1', mockRuleWithConditions1.conditions.all);
      expect(condition).toBe(mockRuleWithConditions1.conditions.all[0]);
    });

    it('should return null if condition not found', () => {
      const condition = findConditionById('c:2', mockRuleWithConditions1.conditions.all);
      expect(condition).toBe(null);
    });

    it('should return null if no conditions', () => {
      const condition = findConditionById('c:1', mockDefaultRule.conditions.all);
      expect(condition).toBe(null);
    });

    it('should find the id in deeply nested structure', () => {
      const condition = findConditionById('c:5', mockRuleNestedConditions.conditions.all);
      // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
      expect(condition).toBe(mockRuleNestedConditions.conditions.all![1].all![2].any![1]);
    });
  });

  describe('forEachCondition', () => {
    it('should return a modified copy', () => {
      const ogConditions = mockRuleNestedConditions.conditions.all;
      const editedConditions = forEachCondition(ogConditions, (condition) => {
        if (condition.id === 'c:5') {
          condition.value = 11;
        }
      });
      expect(editedConditions).not.toBe(ogConditions);
      expect(editedConditions[1].all[2].any[1].value).toBe(11);
    });
  });

  describe('deleteConditionById', () => {
    it('should delete a condition', () => {
      const conditionToDelete = findConditionById('c:5', mockRuleNestedConditions.conditions.all);
      const conditions = mockRuleNestedConditions.conditions.all;
      const newConditions = deleteConditionById('c:5', conditions);
      expect(conditionToDelete).not.toBe(null);
      expect(findConditionById('c:5', newConditions)).toBe(null);
    });
  });
});
