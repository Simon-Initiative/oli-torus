import { HierarchyItemSrc, SchedulingType, StringDate } from './scheduler-slice';

const apiUrl = (sectionSlug: string) => `/api/v1/scheduling/${sectionSlug}`;

export const clearSchedule = async (sectionSlug: string) => {
  const response = await fetch(apiUrl(sectionSlug), {
    method: 'DELETE',
  });
  const data = await response.json();
  if (!data.result || data.result !== 'success') {
    throw new Error('Could not clear schedule ' + response);
  }
  return {
    result: data.result as string,
  };
};

export const loadSchedule = async (sectionSlug: string): Promise<HierarchyItemSrc[]> => {
  const response = await fetch(apiUrl(sectionSlug));
  const data = await response.json();
  if (!data.result || data.result !== 'success') {
    throw new Error('Could not load schedule ' + response);
  }
  return data.resources;
};

export interface ScheduleUpdate {
  start_date: StringDate | null;
  end_date: StringDate | null;
  id: number;
  scheduling_type: SchedulingType;
  manually_scheduled: boolean;
  removed_from_schedule: boolean;
}

export const updateSchedule = async (sectionSlug: string, updates: ScheduleUpdate[]) => {
  const response = await fetch(apiUrl(sectionSlug), {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ updates }),
  });
  const data = await response.json();
  if (!data.result || data.result !== 'success') {
    throw new Error('Could not update schedule ' + response);
  }
  return {
    count: data.count as number,
    result: data.result as string,
  };
};
