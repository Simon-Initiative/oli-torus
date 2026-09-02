import {
  canCreateObjective,
  objectivesForAttachment,
} from 'components/resource/objectives/ObjectivesSelection';
import { Objective } from 'data/content/objective';

const objectives: Objective[] = [
  { id: 1, title: 'Parent', parentIds: null },
  { id: 2, title: 'Another parent', parentIds: [] },
  { id: 3, title: 'Child', parentIds: [1] },
];

describe('objective attachment restrictions', () => {
  it('only offers top-level objectives for well-formed page attachments', () => {
    expect(objectivesForAttachment(objectives, 'page', true)).toEqual(objectives.slice(0, 2));
  });

  it('disables top-level objectives for well-formed activity attachments', () => {
    expect(objectivesForAttachment(objectives, 'activity', true)).toEqual([
      { ...objectives[0], disabled: true },
      { ...objectives[1], disabled: true },
      { ...objectives[2], disabled: false },
    ]);
  });

  it.each([false, undefined])(
    'keeps attachment choices unrestricted when loWellFormed is %s',
    (loWellFormed) => {
      expect(objectivesForAttachment(objectives, 'page', loWellFormed)).toBe(objectives);
      expect(objectivesForAttachment(objectives, 'activity', loWellFormed)).toBe(objectives);
    },
  );

  it('disables just-in-time objective creation for well-formed projects', () => {
    const register = jest.fn();

    expect(canCreateObjective(register, true)).toBe(false);
    expect(canCreateObjective(register, false)).toBe(true);
    expect(canCreateObjective(register)).toBe(true);
    expect(canCreateObjective(undefined, false)).toBe(false);
  });
});
