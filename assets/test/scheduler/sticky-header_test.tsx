import React from 'react';
import { Provider } from 'react-redux';
import { configureStore } from '@reduxjs/toolkit';
import { fireEvent, render, screen } from '@testing-library/react';
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

  it('renders the date header in its own sticky container outside the schedule body table', () => {
    const store = configureStore({
      reducer: { scheduler: schedulerSliceReducer },
      preloadedState: { scheduler: baseState },
    });

    const { container } = render(
      <Provider store={store}>
        <ScheduleGrid {...defaultProps} />
      </Provider>,
    );

    const stickyHeader = container.querySelector('.sticky.top-14.z-10');
    const headerScroll = screen.getByTestId('schedule-header-scroll');
    const bodyScroll = screen.getByTestId('schedule-body-scroll');
    const bodyTableHead = bodyScroll.querySelector('thead');

    expect(stickyHeader).toContainElement(headerScroll);
    expect(bodyTableHead).toBeNull();
  });

  it('keeps the sticky header horizontally aligned with the body scroll position', () => {
    const store = configureStore({
      reducer: { scheduler: schedulerSliceReducer },
      preloadedState: { scheduler: baseState },
    });

    render(
      <Provider store={store}>
        <ScheduleGrid {...defaultProps} />
      </Provider>,
    );

    const headerScroll = screen.getByTestId('schedule-header-scroll');
    const bodyScroll = screen.getByTestId('schedule-body-scroll');

    Object.defineProperty(bodyScroll, 'scrollLeft', {
      value: 120,
      writable: true,
      configurable: true,
    });

    fireEvent.scroll(bodyScroll);

    expect(headerScroll.scrollLeft).toBe(120);
  });
});
