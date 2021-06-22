import React, { useState } from 'react';
import {
  ResourceContent,
  ResourceContext,
  ActivityReference,
  createDefaultStructuredContent,
} from 'data/content/resource';
import { ActivityEditorMap, EditorDesc } from 'data/content/editors';
import { ActivityModelSchema } from 'components/activities/types';
import { invokeCreationFunc } from 'components/activities/creation';
import { Objective, ResourceId } from 'data/content/objective';
import * as Persistence from 'data/persistence/activity';
import guid from 'utils/guid';
import { Popover } from 'react-tiny-popover';
import { ActivityEditContext } from 'data/content/activity';
import { modalActions } from 'actions/modal';
import * as Immutable from 'immutable';

const dismiss = () => (window as any).oliDispatch(modalActions.dismiss());
const display = (c: any) => (window as any).oliDispatch(modalActions.display(c));

import { classNames } from 'utils/classNames';
import { ObjectiveSelection } from 'components/resource/ObjectiveSelection';
import ModalSelection from 'components/modal/ModalSelection';

type AddCallback = (content: ResourceContent, index: number, a?: ActivityEditContext) => void;

const promptForObjectiveSelection = (
  objectives: Immutable.List<Objective>,
  childrenObjectives: Immutable.Map<ResourceId, Immutable.List<Objective>>,
  onRegisterNewObjective: (title: string) => Promise<Objective>,
) => {
  return new Promise((resolve, reject) => {
    const onRegister = (title: string): Promise<Objective> => {
      return new Promise((inner, reject) => {
        onRegisterNewObjective(title).then((objective) => {
          dismiss();

          resolve(
            Immutable.List<ResourceId>([objective.id]),
          );
        });
      });
    };

    const onUseSelected = (selected: Immutable.List<ResourceId>) => {
      dismiss();
      resolve(selected);
    };

    display(
      <ModalSelection
        title="Target learning objectives with this activity"
        hideOkButton={true}
        hideDialogCloseButton={true}
        cancelLabel="Skip this step"
        onInsert={() => {
          dismiss();
          resolve([]);
        }}
        onCancel={() => {
          dismiss();
          resolve([]);
        }}
      >
        <ObjectiveSelection
          objectives={objectives}
          childrenObjectives={childrenObjectives}
          onUseSelected={onUseSelected}
          onRegisterNewObjective={onRegister}
        />
      </ModalSelection>,
    );
  });
};

// Component that presents a drop down to use to add structure
// content or the any of the registered activities
interface AddResourceContentProps {
  editMode: boolean;
  index: number;
  onAddItem: AddCallback;
  isLast: boolean;
  objectives: Immutable.List<Objective>;
  childrenObjectives: Immutable.Map<ResourceId, Immutable.List<Objective>>;
  onRegisterNewObjective: (text: string) => Promise<Objective>;
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
  objectives,
  onRegisterNewObjective,
  childrenObjectives,
}: AddResourceContentProps) => {
  const [isPopoverOpen, setIsPopoverOpen] = useState(false);

  const handleAdd = (editorDesc: EditorDesc) => {
    let model: ActivityModelSchema;
    let selectedObjectives: ResourceId[];

    promptForObjectiveSelection(objectives, childrenObjectives, onRegisterNewObjective).then(
      (objectives: ResourceId[]) =>
        invokeCreationFunc(editorDesc.slug, resourceContext)
          .then((createdModel) => {
            model = createdModel;
            selectedObjectives = objectives;

            return Persistence.create(
              resourceContext.projectSlug,
              editorDesc.slug,
              model,
              objectives,
            );
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
                p[id] = selectedObjectives;
                return p;
              }, {});

            const editor = editorMap[editorDesc.slug];

            const activity: ActivityEditContext = {
              authoringElement: editor.authoringElement as string,
              authoringScript: '',
              description: editor.description,
              friendlyName: editor.friendlyName,
              activitySlug: result.revisionSlug,
              typeSlug: editorDesc.slug,
              activityId: 0,
              title: '',
              model,
              objectives,
            };

            onAddItem(resourceContent, index, activity);
          })
          .catch((err) => {
            // tslint:disable-next-line
            console.error(err);
          }),
    );
  };

  const activityEntries = Object.keys(editorMap).map((k: string) => {
    const editorDesc: EditorDesc = editorMap[k];
    const enabled = editorDesc.globallyAvailable || editorDesc.enabledForProject;
    return (
      <React.Fragment key={editorDesc.slug}>
        {enabled && (
          <button
            className="btn btn-sm insert-activity-btn"
            key={editorDesc.slug}
            onClick={handleAdd.bind(this, editorDesc)}
          >
            {editorDesc.friendlyName}
          </button>
        )}
      </React.Fragment>
    );
  });

  const contentFn = () => (
    <div className="add-resource-popover-content">
      <div className="content">
        <button
          className="btn insert-content-btn"
          onClick={() => onAddItem(createDefaultStructuredContent(), index)}
        >
          <div className="content-icon">
            <span className="material-icons">format_align_left</span>
          </div>
          <div className="content-label">Content</div>
        </button>
      </div>
      <div className="activities">{activityEntries}</div>
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
