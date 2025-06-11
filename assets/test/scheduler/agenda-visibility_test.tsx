import React from 'react';
import { Provider } from 'react-redux';
import { configureStore } from '@reduxjs/toolkit';
import { fireEvent, render, screen } from '@testing-library/react';
import { ScheduleGrid } from '../../src/apps/scheduler/ScheduleGrid';
import { SchedulerState, schedulerSliceReducer } from '../../src/apps/scheduler/scheduler-slice';
import { updateSectionAgenda } from '../../src/apps/scheduler/scheduling-thunk';
import * as thunks from '../../src/apps/scheduler/scheduling-thunk';

// Mock global ResizeObserver to avoid jsdom error
global.ResizeObserver = class {
  observe() {}
  unobserve() {}
  disconnect() {}
} as any;

describe('Agenda Visibility Toggle', () => {
  describe('Reducer Logic', () => {
    const initialState: SchedulerState = {
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
    };

    it('updates agenda to true when fulfilled', () => {
      const nextState = schedulerSliceReducer(
        initialState,
        updateSectionAgenda.fulfilled({ agenda: true }, '', {
          section_slug: 'my-section',
          agenda: true,
        }),
      );

      expect(nextState.agenda).toBe(true);
    });

    it('updates agenda to false when fulfilled', () => {
      const modifiedState = { ...initialState, agenda: true };

      const nextState = schedulerSliceReducer(
        modifiedState,
        updateSectionAgenda.fulfilled({ agenda: false }, '', {
          section_slug: 'my-section',
          agenda: false,
        }),
      );

      expect(nextState.agenda).toBe(false);
    });
  });

  describe('UI Behavior', () => {
    const defaultProps = {
      startDate: '2024-01-01',
      endDate: '2024-12-31',
      section_slug: 'test-section',
      onReset: jest.fn(),
      onClear: jest.fn(),
      onViewSelected: jest.fn(),
      onToggleAgenda: jest.fn(),
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
    };

    const createTestStore = (preloadedState: SchedulerState) =>
      configureStore({
        reducer: { scheduler: schedulerSliceReducer },
        preloadedState: { scheduler: preloadedState },
      });

    it('dispatches updateSectionAgenda on toggle click (false → true)', () => {
      const store = createTestStore({ ...baseState, agenda: false });
      const spy = jest.spyOn(thunks, 'updateSectionAgenda');

      render(
        <Provider store={store}>
          <ScheduleGrid {...defaultProps} />
        </Provider>,
      );

      const checkbox = screen.getByRole('checkbox', { name: /agenda visibility/i });
      expect(checkbox).not.toBeChecked();

      fireEvent.click(checkbox);

      expect(spy).toHaveBeenCalledWith({ section_slug: 'test-section', agenda: true });
    });

    it('dispatches updateSectionAgenda on toggle click (true → false)', () => {
      const store = createTestStore({ ...baseState, agenda: true });
      const spy = jest.spyOn(thunks, 'updateSectionAgenda');

      render(
        <Provider store={store}>
          <ScheduleGrid {...defaultProps} />
        </Provider>,
      );

      const checkbox = screen.getByRole('checkbox', { name: /agenda visibility/i });
      expect(checkbox).toBeChecked();

      fireEvent.click(checkbox);

      expect(spy).toHaveBeenCalledWith({ section_slug: 'test-section', agenda: false });
    });
  });
});
