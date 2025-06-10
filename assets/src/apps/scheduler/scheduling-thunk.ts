import { createAsyncThunk } from '@reduxjs/toolkit';
import uniq from 'lodash/uniq';
import { dateTimeInTorusFormat, dateWithoutTimeLabel } from './date-utils';
import { SchedulerAppState } from './scheduler-reducer';
import { StringDate, getScheduleItem } from './scheduler-slice';
import { ScheduleUpdate, clearSchedule, loadSchedule, updateSchedule } from './scheduling-service';

interface StartupPayload {
  start_date: StringDate;
  end_date: StringDate;
  title: string;
  section_slug: string;
  display_curriculum_item_numbering: boolean;
  preferred_scheduling_time: string;
}

interface ClearPayload {
  section_slug: string;
}

export const clearSectionSchedule = createAsyncThunk(
  'schedule/clear',
  async (param: ClearPayload, thunkAPI) => {
    return clearSchedule(param.section_slug);
  },
);

export const scheduleAppFlushChanges = createAsyncThunk(
  'schedule/flushChanges',
  async (param, thunkAPI) => {
    const state = thunkAPI.getState() as SchedulerAppState;
    const dirty = uniq(state.scheduler.dirty);
    const schedule = state.scheduler.schedule;

    if (dirty.length === 0) return;

    const updates: ScheduleUpdate[] = dirty
      .map((id) => {
        const item = getScheduleItem(id, schedule);
        if (!item) return null;
        return {
          start_date: item.graded
            ? dateTimeInTorusFormat(item.startDateTime)
            : dateWithoutTimeLabel(item.startDate),
          end_date:
            item.scheduling_type === 'due_by'
              ? dateTimeInTorusFormat(item.endDateTime) // For due-by we need the time as well as the date.
              : dateWithoutTimeLabel(item.endDate),
          id: item.id,
          scheduling_type: item.scheduling_type,
          manually_scheduled: item.manually_scheduled,
          removed_from_schedule: item.removed_from_schedule,
        };
      })
      .filter((i) => !!i) as ScheduleUpdate[];
    console.info(
      'Saving: ',
      dirty
        .map((id) => getScheduleItem(id, schedule))
        .map((i) => `${i?.title} ${i?.numbering_index}`)
        .join(', '),
    );
    try {
      await updateSchedule(state.scheduler.sectionSlug, updates);
      window.dispatchEvent(new Event('schedule-updated'));
    } catch (e) {
      console.error(e);
      window.dispatchEvent(new Event('schedule-update-failed'));
      throw e;
    }
  },
);

export const scheduleAppStartup = createAsyncThunk(
  'schedule/startup',
  async (
    {
      start_date,
      end_date,
      title,
      section_slug,
      display_curriculum_item_numbering,
      preferred_scheduling_time,
    }: StartupPayload,
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    thunkAPI,
  ) => {
    const response = await loadSchedule(section_slug);
    return {
      schedule: response,
      preferred_scheduling_time,
      start_date,
      end_date,
      title,
      display_curriculum_item_numbering,
      section_slug,
    };
  },
);
