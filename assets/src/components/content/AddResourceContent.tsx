import React, { useState } from 'react';
import {
  ResourceContent,
  ResourceContext,
  ActivityReference,
  createDefaultStructuredContent,
  createDefaultSelection,
} from 'data/content/resource';
import { ActivityEditorMap, EditorDesc } from 'data/content/editors';
import { ActivityModelSchema } from 'components/activities/types';
import { invokeCreationFunc } from 'components/activities/creation';
import { Objective, ResourceId } from 'data/content/objective';
import * as Persistence from 'data/persistence/activity';
import guid from 'utils/guid';
import { Popover } from 'react-tiny-popover';
import { ActivityEditContext } from 'data/content/activity';
import * as Immutable from 'immutable';

import { classNames } from 'utils/classNames';

type AddCallback = (content: ResourceContent, index: number, a?: ActivityEditContext) => void;

// Component that presents a drop down to use to add structure
// content or the any of the registered activities
interface AddResourceContentProps {
  editMode: boolean;
  index: number;
  onAddItem: AddCallback;
  isLast: boolean;
  objectives: Immutable.List<Objective>;
  childrenObjectives: Immutable.Map<ResourceId, Immutable.List<Objective>>;
  onRegisterNewObjective: (objective: Objective) => void;
  editorMap: ActivityEditorMap;
  resourceContext: ResourceContext;
}
export const AddResourceContent = ({
  editMode,
  index,
  onAddItem,
  editorMap,
  resourceContext,
  isLast,
}: AddResourceContentProps) => {
  const [isPopoverOpen, setIsPopoverOpen] = useState(false);

  const handleAdd = (editorDesc: EditorDesc) => {
    let model: ActivityModelSchema;

    invokeCreationFunc(editorDesc.slug, resourceContext)
      .then((createdModel) => {
        model = createdModel;

        return Persistence.create(resourceContext.projectSlug, editorDesc.slug, model, []);
      })
      .then((result: Persistence.Created) => {
        const resourceContent: ActivityReference = {
          type: 'activity-reference',
          id: guid(),
          activitySlug: result.revisionSlug,
          purpose: 'none',
          children: [],
        };

        // For every part that we find in the model, we attach the selected
        // objectives to it
        const objectives = model.authoring.parts
          .map((p: any) => p.id)
          .reduce((p: any, id: string) => {
            p[id] = [];
            return p;
          }, {});

        const editor = editorMap[editorDesc.slug];

        const activity: ActivityEditContext = {
          authoringElement: editor.authoringElement as string,
          description: editor.description,
          friendlyName: editor.friendlyName,
          activitySlug: result.revisionSlug,
          typeSlug: editorDesc.slug,
          activityId: result.resourceId,
          title: editor.friendlyName,
          model,
          objectives,
        };

        onAddItem(resourceContent, index, activity);
      })
      .catch((err) => {
        // tslint:disable-next-line
        console.error(err);
      });
  };

  const activityEntries = Object.keys(editorMap)
    .map((k: string) => {
      const editorDesc: EditorDesc = editorMap[k];
      const enabled = editorDesc.globallyAvailable || editorDesc.enabledForProject;

      return enabled ? (
        <a
          href="#"
          key={editorDesc.slug}
          className="list-group-item list-group-item-action flex-column align-items-start"
          onClick={handleAdd.bind(this, editorDesc)}
        >
          <div className="type-label"> {editorDesc.friendlyName}</div>
          <div className="type-description"> {editorDesc.description}</div>
        </a>
      ) : null;
    })
    .filter((e) => e !== null);

  const contentFn = () => (
    <div className="add-resource-popover-content">
      <div className="header">Insert Content</div>
      <div className="list-group">
        <a
          href="#"
          key={'static_html_content'}
          className="list-group-item list-group-item-action flex-column align-items-start"
          onClick={() => onAddItem(createDefaultStructuredContent(), index)}
        >
          <div className="type-label">HTML</div>
          <div className="type-description">
            Mixed HTML elements including text, tables, images, video
          </div>
        </a>
      </div>
      <hr />
      <div className="header">Insert Activity</div>
      <div className="list-group">{activityEntries}</div>
      <hr />
      <div className="header">Insert Other</div>
      <div className="list-group">
        <a
          href="#"
          key={'static_activity_bank'}
          className="list-group-item list-group-item-action flex-column align-items-start"
          onClick={() => onAddItem(createDefaultSelection(), index)}
        >
          <div className="type-label">Activity Bank Selection</div>
          <div className="type-description">
            Select different activities at random according to defined criteria
          </div>
        </a>
      </div>
    </div>
  );

  const [latestClickEvent, setLatestClickEvent] = useState<MouseEvent>();
  const togglePopover = (e: React.MouseEvent) => {
    setIsPopoverOpen(!isPopoverOpen);
    setLatestClickEvent(e.nativeEvent);
  };

  return (
    <React.Fragment>
      <div
        className={classNames([
          'add-resource-content',
          isPopoverOpen ? 'active' : '',
          isLast ? 'add-resource-content-last' : '',
          editMode ? '' : 'disabled',
        ])}
        onClick={togglePopover}
      >
        {editMode && (
          <React.Fragment>
            <div className="insert-button-container">
              <Popover
                containerClassName="add-resource-popover"
                onClickOutside={(e: any) => {
                  if (e !== latestClickEvent) {
                    setIsPopoverOpen(false);
                  }
                }}
                isOpen={isPopoverOpen}
                align="start"
                content={contentFn}
              >
                <div className="insert-button">
                  <i className="fa fa-plus"></i>
                </div>
              </Popover>
            </div>
            <div className="insert-adornment"></div>
          </React.Fragment>
        )}
      </div>
      {isLast && (
        <div className="insert-label my-4 text-center">
          <button onClick={togglePopover} disabled={!editMode} className="btn btn-sm btn-light">
            Add Content or Activity
          </button>
        </div>
      )}
    </React.Fragment>
  );
};
