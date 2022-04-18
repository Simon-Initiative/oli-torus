import { DiagnosticTypes } from 'apps/authoring/components/Modal/diagnostics/DiagnosticTypes';
import { diagnosePage } from 'apps/authoring/store/groups/layouts/deck/actions/validate';
import { clone } from 'utils/common';
import { activityWithDuplicateParts, activityWithInvalidPartIds, page } from './diagnostics_mocks';

describe('Adaptive Diagnostics', () => {
  it('should be able to detect duplicate part ids on the same screen (activity)', () => {
    const mockPage = clone(page);
    const activityDB = [activityWithDuplicateParts];
    const sequence = [
      {
        activitySlug: activityWithDuplicateParts.activitySlug,
        custom: {
          sequenceId: `${activityWithDuplicateParts.activitySlug}_sequenceId`,
          sequenceName: activityWithDuplicateParts.title,
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

  it('should be able to detect part ids with invalid (problematic) characters', () => {
    const mockPage = clone(page);
    const activityDB = [activityWithInvalidPartIds];
    const sequence = [
      {
        activitySlug: activityWithInvalidPartIds.activitySlug,
        custom: {
          sequenceId: `${activityWithInvalidPartIds.activitySlug}_sequenceId`,
          sequenceName: activityWithInvalidPartIds.title,
        },
        type: 'activity-reference',
        resourceId: activityWithInvalidPartIds.resourceId,
      },
    ];

    const errors = diagnosePage(mockPage, activityDB, sequence);

    expect(errors.length).toBe(1);
    expect(errors[0].problems.length).toBe(1);
    expect(
      errors[0].problems.every((problem) => {
        const typeMatch = problem.type === DiagnosticTypes.PATTERN;
        const ownerMatch = problem.owner.resourceId === activityWithInvalidPartIds.resourceId;

        return typeMatch && ownerMatch;
      }),
    ).toBe(true);
  });
});
