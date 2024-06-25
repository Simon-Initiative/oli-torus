import React, { useEffect, useState } from 'react';
import { LoadingSpinner, LoadingSpinnerSize } from 'components/common/LoadingSpinner';
import { ReportContent } from 'data/content/resource';
import * as Persistence from 'data/persistence/resource';
import { ActivityWithReportOption } from 'data/persistence/resource';
import {
  Description,
  Icon,
  OutlineGroup,
  OutlineGroupProps,
  resourceGroupTitle,
} from './OutlineItem';
import { ReportBlock } from './ReportBlock';
import { EditorProps } from './createEditor';

export enum ActivitiesWithReportType {
  REQUEST,
  SUCCESS,
  FAILURE,
}

type ActivitiesWithReportState =
  | { type: ActivitiesWithReportType.REQUEST }
  | {
      type: ActivitiesWithReportType.SUCCESS;
      activities: ActivityWithReportOption[];
      selected: ActivityWithReportOption;
    }
  | { type: ActivitiesWithReportType.FAILURE; error: string };

interface ReportEditorProps extends EditorProps {
  contentItem: ReportContent;
}

export const ReportEditor = ({
  editMode,
  contentItem,
  projectSlug,
  canRemove,
  onEdit,
  onRemove,
}: ReportEditorProps) => {
  const [activitiesWithReportState, setActivitiesWithReportState] =
    useState<ActivitiesWithReportState>({
      type: ActivitiesWithReportType.REQUEST,
    });

  useEffect(() => {
    Persistence.activitiesWithReport(projectSlug)
      .then((result) => {
        if (result.type === 'success') {
          const value = result.activities.find((a) => a.id === contentItem.activityId);
          if (value) {
            setActivitiesWithReportState({
              type: ActivitiesWithReportType.SUCCESS,
              activities: result.activities,
              selected: value,
            });
          } else {
            setActivitiesWithReportState({
              type: ActivitiesWithReportType.FAILURE,
              error: 'activity cannot be found',
            });
          }
        } else {
          setActivitiesWithReportState({
            type: ActivitiesWithReportType.FAILURE,
            error: result.message,
          });
        }
      })
      .catch(({ message }) =>
        setActivitiesWithReportState({
          type: ActivitiesWithReportType.FAILURE,
          error: message,
        }),
      );
  }, []);

  const displayActivity = () => {
    switch (activitiesWithReportState.type) {
      case ActivitiesWithReportType.REQUEST:
        return (
          <LoadingSpinner size={LoadingSpinnerSize.Medium} align="left">
            Loading
          </LoadingSpinner>
        );
      case ActivitiesWithReportType.SUCCESS:
        return (
          <dl className="text-gray-900 divide-y divide-gray-200 dark:text-white dark:divide-gray-700">
            <div className="flex flex-col pb-2">
              <dt className="mb-1 text-gray-500 dark:text-gray-400">Activity Title</dt>
              <dd className="font-semibold">{activitiesWithReportState.selected.title}</dd>
            </div>
            {activitiesWithReportState.selected.page && (
              <div className="flex flex-col py-2">
                <dt className="mb-1 text-gray-500 dark:text-gray-400">Parent Page</dt>
                <dd className="font-semibold">
                  <a href={activitiesWithReportState.selected.page.url} title="parent page">
                    {activitiesWithReportState.selected.page.title}
                  </a>
                </dd>
              </div>
            )}
            <div className="flex flex-col pt-2">
              <dt className="mb-1 text-gray-500 dark:text-gray-400">Activity Type</dt>
              <dd className="font-semibold">{activitiesWithReportState.selected.type}</dd>
            </div>
          </dl>
        );
      case ActivitiesWithReportType.FAILURE:
        return (
          <LoadingSpinner failed size={LoadingSpinnerSize.Medium} align="left">
            An error occurred
          </LoadingSpinner>
        );
    }
  };

  return (
    <ReportBlock
      editMode={editMode}
      contentItem={contentItem}
      canRemove={canRemove}
      onRemove={() => onRemove(contentItem.id)}
      onEdit={onEdit}
    >
      {displayActivity()}
    </ReportBlock>
  );
};

interface ReportOutlineItemProps extends OutlineGroupProps {
  contentItem: ReportContent;
}

export const ReportOutlineItem = (props: ReportOutlineItemProps) => {
  const { contentItem } = props;

  return (
    <OutlineGroup {...props}>
      <Icon iconName="fas fa-area-chart" />
      <Description title={resourceGroupTitle(contentItem)}>items</Description>
    </OutlineGroup>
  );
};
