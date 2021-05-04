import { check } from 'adaptivity/rules-engine';
import { complexRuleWithMultipleActions, defaultCorrectRule, disabledCorrectRule, mockState } from './rules_mocks';

describe('Rules Engine', () => {
  it('should not break if empty state is passed', async () => {
    const successEvents = await check({}, []);
    expect(successEvents).toEqual([]);
  });

  it('should return successful events of rules with no conditions', async () => {
    const events = await check(mockState, [defaultCorrectRule]);
    expect(events.length).toEqual(1);
    expect(events[0]).toEqual(defaultCorrectRule.event);
  });

  it('should evaluate complex conditions', async () => {
    const events = await check(mockState, [complexRuleWithMultipleActions, defaultCorrectRule]);
    expect(events.length).toEqual(2);
    expect(events[0].type).toEqual(complexRuleWithMultipleActions.event.type);
  });

  it('should not process disabled rules', async () => {
    const events = await check(mockState, [disabledCorrectRule]);
    expect(events.length).toEqual(0);
  });
});
