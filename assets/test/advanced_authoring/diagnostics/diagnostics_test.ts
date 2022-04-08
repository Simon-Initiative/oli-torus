import { DiagnosticTypes } from 'apps/authoring/components/Modal/diagnostics/DiagnosticTypes';
import { diagnosePage } from 'apps/authoring/store/groups/layouts/deck/actions/validate';
import { clone } from 'utils/common';
import { activityWithDuplicateParts, page } from './diagnostics_mocks';

describe('Adaptive Diagnostics', () => {
  it('should be able to detect duplicate part ids on the same screen (activity)', () => {
    const mockPage = clone(page);
    const activityDB = [activityWithDuplicateParts];
    const sequence = [
      {
        activitySlug: 'screen1_4j5rc',
        custom: {
          sequenceId: 'screen1',
          sequenceName: 'Activity with Duplicate Parts',
        },
        type: 'activity-reference',
        resourceId: activityWithDuplicateParts.resourceId,
      },
    ];

    const errors = diagnosePage(mockPage, activityDB, sequence);

    expect(errors.length).toBe(1);
    expect(errors[0].problems.length).toBe(2);
    expect(
      errors[0].problems.every((problem) => {
        const typeMatch = problem.type === DiagnosticTypes.DUPLICATE;
        const ownerMatch = problem.owner.resourceId === activityWithDuplicateParts.resourceId;

        return typeMatch && ownerMatch;
      }),
    ).toBe(true);
  });
});
