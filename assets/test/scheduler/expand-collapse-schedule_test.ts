import {
  AssessmentLayoutType,
  HierarchyItem,
  ScheduleItemType,
  collapseAllContainers,
  expandAllContainers,
  hasContainers,
  isContainerExpanded,
  schedulerSliceReducer,
  toggleContainer,
} from '../../src/apps/scheduler/scheduler-slice';

describe('expand/collapse containers', () => {
  const container1: HierarchyItem = {
    id: 1,
    resource_id: 1,
    resource_type_id: ScheduleItemType.Container,
    title: 'Container 1',
    numbering_level: 1,
    numbering_index: 1,
    scheduling_type: 'read_by',
    manually_scheduled: false,
    graded: false,
    children: [],
    startDate: null,
    endDate: null,
    startDateTime: null,
    endDateTime: null,
    start_date: '',
    end_date: '',
    removed_from_schedule: false,
  };

  const rootContainer: HierarchyItem = {
    ...container1,
    id: 0,
    numbering_level: 0,
    numbering_index: 1,
  };

  const baseState: { scheduler: ReturnType<typeof schedulerSliceReducer> } = {
    scheduler: {
      schedule: [rootContainer, container1],
      expandedContainers: {},
      startDate: null,
      endDate: null,
      selectedId: null,
      appLoading: false,
      saving: false,
      title: '',
      displayCurriculumItemNumbering: true,
      dirty: [],
      sectionSlug: '',
      errorMessage: null,
      weekdays: [false, true, true, true, true, true, false],
      preferredSchedulingTime: { hour: 23, minute: 59, second: 59 },
      searchQuery: '',
      showRemoved: false,
      agenda: true,
      assessmentLayoutType: AssessmentLayoutType.ContentSequence,
    },
  };

  it('should toggle a container', () => {
    const nextState = schedulerSliceReducer(baseState.scheduler, toggleContainer(1));
    expect(nextState.expandedContainers[1]).toBe(true);

    const revertedState = schedulerSliceReducer(nextState, toggleContainer(1));
    expect(revertedState.expandedContainers[1]).toBeFalsy();
  });

  it('should expand all containers', () => {
    const nextState = schedulerSliceReducer(baseState.scheduler, expandAllContainers());
    expect(Object.keys(nextState.expandedContainers)).toHaveLength(2);
    expect(nextState.expandedContainers).toEqual({ 0: true, 1: true });
  });

  it('should collapse all containers', () => {
    const expandedState = schedulerSliceReducer(baseState.scheduler, expandAllContainers());
    const collapsedState = schedulerSliceReducer(expandedState, collapseAllContainers());
    expect(collapsedState.expandedContainers).toEqual({});
  });

  it('isContainerExpanded selector should return true if container is expanded', () => {
    const stateWithExpanded = {
      ...baseState,
      scheduler: {
        ...baseState.scheduler,
        expandedContainers: { 1: true },
      },
    };
    expect(isContainerExpanded(stateWithExpanded, 1)).toBe(true);
    expect(isContainerExpanded(stateWithExpanded, 999)).toBe(false);
  });

  it('hasContainers should return true only if there are non-root containers', () => {
    const withOnlyRoot = {
      ...baseState,
      scheduler: {
        ...baseState.scheduler,
        schedule: [rootContainer],
      },
    };
    expect(hasContainers(withOnlyRoot)).toBe(false);

    const withSubContainer = {
      ...baseState,
      scheduler: {
        ...baseState.scheduler,
        schedule: [rootContainer, container1],
      },
    };
    expect(hasContainers(withSubContainer)).toBe(true);
  });
});
