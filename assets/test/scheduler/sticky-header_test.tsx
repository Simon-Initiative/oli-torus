import React from 'react';
import { Provider } from 'react-redux';
import { configureStore } from '@reduxjs/toolkit';
import { render } from '@testing-library/react';
import { ScheduleGrid } from '../../src/apps/scheduler/ScheduleGrid';
import {
  AssessmentLayoutType,
  SchedulerState,
  schedulerSliceReducer,
} from '../../src/apps/scheduler/scheduler-slice';

global.ResizeObserver = class {
  observe() {}
  unobserve() {}
  disconnect() {}
} as any;

describe('ScheduleGrid sticky header', () => {
  const defaultProps = {
    startDate: '2024-01-01',
    endDate: '2024-12-31',
    section_slug: 'test-section',
    onReset: jest.fn(),
    onClear: jest.fn(),
    onViewSelected: jest.fn(),
  };

  const baseState: SchedulerState = {
    agenda: false,
    schedule: [],
    expandedContainers: {},
    searchQuery: '',
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
    showRemoved: false,
    assessmentLayoutType: AssessmentLayoutType.ContentSequence,
  };

  it('keeps the date header sticky while the schedule body scrolls', () => {
    const store = configureStore({
      reducer: { scheduler: schedulerSliceReducer },
      preloadedState: { scheduler: baseState },
    });

    const { container } = render(
      <Provider store={store}>
        <ScheduleGrid {...defaultProps} />
      </Provider>,
    );

    const tableHead = container.querySelector('thead');

    expect(tableHead).toHaveClass('sticky');
    expect(tableHead).toHaveClass('top-14');
    expect(tableHead).toHaveClass('z-10');
  });
});
