import React, { useEffect, useMemo, useRef } from 'react';
import { Dropdown } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { useCallbackRef, useResizeObserver } from '@restart/hooks';
import { DateWithoutTime } from 'epoq';
import { modeIsDark } from 'components/misc/DarkModeSelector';
import { ClearIcon, CollapseAllIcon, ExpandAllIcon, SearchIcon } from 'components/misc/icons/Icons';
import { ViewMode } from './ScheduleEditor';
import { ScheduleHeaderRow } from './ScheduleHeader';
import { ScheduleLine } from './ScheduleLine';
import { generateDayGeometry } from './date-utils';
import {
  VisibleHierarchyItem,
  getVisibleSchedule,
  isAnyVisibleContainerExpanded,
} from './schedule-selectors';
import { SchedulerAppState } from './scheduler-reducer';
import {
  ScheduleItemType,
  collapseAllContainers,
  collapseVisibleContainers,
  expandAllContainers,
  expandVisibleContainers,
  hasContainers,
  setSearchQuery,
} from './scheduler-slice';
import { updateSectionAgenda } from './scheduling-thunk';

interface GridProps {
  startDate: string;
  endDate: string;
  section_slug: string;
  onReset: () => void;
  onClear: () => void;
  onViewSelected: (view: ViewMode) => void;
}

const rowPalette = [
  '#BC1A27',
  '#D97B68',
  '#94849B',
  '#973F7D',
  '#B9097E',
  '#737373',
  '#CC8100',
  '#869A13',
  '#4F6831',
  '#2BA3AB',
  '#0F7D85',
  '#58759D',
];
const rowPaletteDark = [
  '#FD7782',
  '#FCE7E3',
  '#E3D4E9',
  '#E58FCC',
  '#FF61CA',
  '#CFB5B5',
  '#FFC96B',
  '#E4FE4D',
  '#A1D463',
  '#82EBF2',
  '#33F1FF',
  '#AFC5E4',
];

export const ScheduleGrid: React.FC<GridProps> = ({
  startDate,
  endDate,
  section_slug,
  onReset,
  onClear,
  onViewSelected,
}) => {
  const [barContainer, attachBarContainer] = useCallbackRef<HTMLElement>();
  const rect = useResizeObserver(barContainer || null);
  const agendaEnabled = useSelector((state: SchedulerAppState) => state.scheduler.agenda);

  const schedule = useSelector(getVisibleSchedule) as VisibleHierarchyItem[];
  const isScheduled = schedule.some((item: any) => item.startDateTime && item.endDateTime);
  const dayGeometry = useMemo(
    () =>
      generateDayGeometry(
        new DateWithoutTime(startDate),
        new DateWithoutTime(endDate),
        rect?.width || 0,
      ),
    [rect?.width, startDate, endDate],
  );

  const dispatch = useDispatch();
  const anyExpanded = useSelector(isAnyVisibleContainerExpanded);

  const expandedContainers = useSelector(
    (state: SchedulerAppState) => state.scheduler.expandedContainers,
  );
  const canToggle = useSelector(hasContainers);
  const searchQuery = useSelector((state: SchedulerAppState) => state.scheduler.searchQuery || '');
  const prevSearchRef = useRef(searchQuery);

  useEffect(() => {
    if (prevSearchRef.current && !searchQuery) {
      dispatch(collapseAllContainers());
    }

    prevSearchRef.current = searchQuery;
  }, [searchQuery, dispatch]);

  useEffect(() => {
    if (searchQuery) {
      const visibleContainers = collectVisibleContainerIds(schedule);

      const allExpanded = visibleContainers.every((id) => expandedContainers[id]);
      if (!allExpanded) {
        dispatch(expandVisibleContainers(visibleContainers));
      }
    }
  }, [searchQuery, schedule]);

  const collectVisibleContainerIds = (nodes: VisibleHierarchyItem[]): number[] => {
    const result: number[] = [];
    const dfs = (items: VisibleHierarchyItem[]) => {
      for (const node of items) {
        if (node.resource_type_id === ScheduleItemType.Container) {
          result.push(node.id);
          dfs(node.children);
        }
      }
    };
    dfs(nodes);
    return result;
  };

  const handleClick = () => {
    const isSearchActive = !!searchQuery;

    const visibleContainers = collectVisibleContainerIds(schedule);
    const allExpanded = visibleContainers.every((id) => expandedContainers[id]);

    if (isSearchActive) {
      if (allExpanded) {
        dispatch(collapseVisibleContainers(visibleContainers));
      } else {
        dispatch(expandVisibleContainers(visibleContainers));
      }
    } else {
      const hasExpanded = Object.values(expandedContainers).some((val) => val);
      hasExpanded ? dispatch(collapseAllContainers()) : dispatch(expandAllContainers());
    }
  };

  const onToggleAgenda = () => {
    dispatch(updateSectionAgenda({ section_slug, agenda: !agendaEnabled }));
  };

  return (
    <div className="pb-20">
      <div className="w-full flex justify-center flex-col bg-[#F2F9FF] dark:bg-[#1F1D23]">
        <div className="container mx-auto">
          <div className="flex flex-row justify-between gap-x-4 mb-6 px-2">
            <div>
              Start organizing your course with the interactive scheduling tool. Set dates for
              course content, and manage content by right-clicking to remove or re-add it. All
              scheduled items will appear in the student schedule and upcoming agenda.
            </div>
            <div className="flex flex-row gap-x-4 items-start py-1">
              {isScheduled ? (
                <button className="btn btn-sm btn-primary whitespace-nowrap" onClick={onReset}>
                  <i className="fa fa-undo-alt" /> Reset Schedule
                </button>
              ) : (
                <button className="btn btn-sm btn-primary whitespace-nowrap" onClick={onReset}>
                  <i className="fa fa-calendar" /> Set Schedule
                </button>
              )}
            </div>
          </div>
        </div>
      </div>
      <div className="flex flex-row gap-x-4 justify-start items-center w-auto h-[51px] mb-6 ml-[270px] mr-2 px-8 bg-white dark:bg-black shadow-[0px_2px_6.099999904632568px_0px_rgba(0,0,0,0.10)]">
        {/* Agenda Visibility Toggle */}
        <form id="toggle_switch_form" className="mr-2">
          <label className="flex flex-row gap-x-4 items-center cursor-pointer ">
            <span
              className={`justify-start text-sm font-bold transition-colors duration-300
                          ${
                            agendaEnabled
                              ? 'text-[#0062F2] dark:text-[#4ca6ff] hover:text-[#1B67B2]'
                              : 'text-[#5c5d69] dark:text-[#eeebf5] hover:text-[#1B67B2]'
                          }`}
            >
              Agenda Visibility
            </span>
            <input
              id="toggle_switch_checkbox"
              type="checkbox"
              name="agenda_visibility"
              className="sr-only peer"
              checked={agendaEnabled}
              onChange={onToggleAgenda}
            />
            <div
              className="relative w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4
                  peer-focus:ring-primary-300 dark:peer-focus:ring-primary-800 rounded-full
                  peer dark:bg-gray-700 peer-checked:after:translate-x-full rtl:peer-checked:after:-translate-x-full
                  peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px]
                  after:start-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5
                  after:w-5 after:transition-transform dark:border-gray-600 peer-checked:bg-primary
                  after:duration-300 after:ease-in-out transition-colors duration-300 ease-in-out"
            ></div>
          </label>
        </form>

        {/* Search Bar  */}
        <div className="relative w-[461px]">
          <SearchIcon className="text-[#383A44] dark:text-white absolute left-3 top-1/2 -translate-y-1/2" />

          <input
            className="w-[461px] h-9 pl-10 pr-3 dark:bg-[#2A282D] dark:text-[#eeebf5] rounded-md border border-[#CED1D9] dark:border-[#514C59]"
            type="text"
            placeholder="Search Schedule..."
            value={searchQuery}
            onChange={(e) => dispatch(setSearchQuery(e.target.value))}
          />
        </div>

        {/* Expand/Collapse All button */}
        <button
          id="toggle_expand_button"
          className={`flex items-center space-x-3 font-medium disabled:opacity-50 disabled:cursor-not-allowed
                      ${
                        anyExpanded
                          ? 'text-[#0062F2] dark:text-[#4CA6FF] font-bold'
                          : 'text-[#353740] dark:text-[#EEEBF5]'
                      }
                      hover:text-[#1B67B2] dark:hover:text-[#99CCFF] hover:font-bold
                    `}
          onClick={handleClick}
          title={!canToggle ? 'No expandable containers available' : undefined}
          disabled={!canToggle}
        >
          {anyExpanded ? <CollapseAllIcon className="ml-2" /> : <ExpandAllIcon className="ml-2" />}
          <span>{anyExpanded ? 'Collapse All' : 'Expand All'}</span>
        </button>

        {/* View Dropdown */}
        <Dropdown>
          <Dropdown.Toggle
            id="bottom-panel-add-context-trigger"
            variant="button"
            className="text-[#0062F2] dark:text-white btn btn-sm flex gap-1 items-center"
          >
            <i className="fa-regular fa-eye" />
            <span className="justify-start text-sm font-bold dark:font-normal dark:text-[#eeebf5]">
              View
            </span>
          </Dropdown.Toggle>

          <Dropdown.Menu>
            <Dropdown.Item
              onClick={() => {
                onViewSelected(ViewMode.AGENDA);
              }}
            >
              View Agenda
            </Dropdown.Item>
            <Dropdown.Item
              onClick={() => {
                onViewSelected(ViewMode.SCHEDULE);
              }}
            >
              View Schedule
            </Dropdown.Item>
          </Dropdown.Menu>
        </Dropdown>

        {/* Clear Schedule button */}
        <button
          id="clear-schedule"
          className="btn btn-sm flex gap-1 items-center"
          onClick={onClear}
        >
          <ClearIcon className="text-[#0062F2] dark:text-white ml-2" />
          <span className="justify-start text-[#0062F2] text-sm font-bold dark:font-normal dark:text-[#eeebf5]">
            Clear
          </span>
        </button>
      </div>
      <div className="w-full px-4">
        <table className="select-none schedule_table border-t-0 border-l-0">
          <thead className="sticky top-14 z-10">
            <ScheduleHeaderRow
              labels={true}
              attachBarContainer={attachBarContainer}
              dayGeometry={dayGeometry}
            />
          </thead>
          <tbody>
            {schedule
              .filter((item) => !item.removed_from_schedule)
              .map((item, index) => (
                <ScheduleLine
                  key={item.id}
                  index={index}
                  indent={0}
                  item={item}
                  rowColor={
                    modeIsDark()
                      ? rowPaletteDark[index % rowPaletteDark.length]
                      : rowPalette[index % rowPalette.length]
                  }
                  dayGeometry={dayGeometry}
                />
              ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};
