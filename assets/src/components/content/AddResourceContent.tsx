import React, { useState } from 'react';
import { ResourceContent, Activity, ResourceContext, ActivityReference,
  createDefaultStructuredContent } from 'data/content/resource';
import { ActivityEditorMap, EditorDesc } from 'data/content/editors';
import { ActivityModelSchema } from 'components/activities/types';
import { invokeCreationFunc } from 'components/activities/creation';
import { Objective, ObjectiveSlug } from 'data/content/objective';
import * as Persistence from 'data/persistence/activity';
import guid from 'utils/guid';
import Popover from 'react-tiny-popover';

import { modalActions } from 'actions/modal';
import * as Immutable from 'immutable';

const dismiss = () => (window as any).oliDispatch(modalActions.dismiss());
const display = (c: any) => (window as any).oliDispatch(modalActions.display(c));

import './AddResourceContent.scss';
import { classNames } from 'utils/classNames';
import { ObjectiveSelection } from 'components/resource/ObjectiveSelection';
import ModalSelection from 'components/modal/ModalSelection';

type AddCallback = (content: ResourceContent, index: number, a? : Activity) => void;


const promptForObjectiveSelection
  = (objectives: Immutable.List<Objective>,
    childrenObjectives: Immutable.Map<ObjectiveSlug, Immutable.List<Objective>>,
    onRegisterNewObjective: (title: string) => Promise<Objective>) => {

    return new Promise((resolve, reject) => {

      const onRegister = (title: string) : Promise<Objective> => {
        return new Promise((inner, reject) => {
          onRegisterNewObjective(title)
          .then((objective) => {
            dismiss();
            resolve(Immutable.List<ObjectiveSlug>([objective.slug]));
          });
        });
      };

      const onUseSelected = (selected: Immutable.List<ObjectiveSlug>) => {
        dismiss();
        resolve(selected);
      };

      display(<ModalSelection title="Target learning objectives with this activity"
        hideOkButton={true}
        cancelLabel="Skip this step"
        onInsert={() => { dismiss(); resolve([]); }}
        onCancel={() => { dismiss(); resolve([]); }}>

        <ObjectiveSelection objectives={objectives}
          childrenObjectives={childrenObjectives}
          onUseSelected={onUseSelected}
          onRegisterNewObjective={onRegister}/>
      </ModalSelection>);
    });

  };


// Component that presents a drop down to use to add structure
// content or the any of the registered activities
export const AddResourceContent = (
  { editMode, index, onAddItem, editorMap, resourceContext, isLast,
    objectives, onRegisterNewObjective, childrenObjectives }
  : {editMode: boolean, index: number, onAddItem: AddCallback, isLast: boolean,
    objectives: Immutable.List<Objective>,
    childrenObjectives: Immutable.Map<ObjectiveSlug, Immutable.List<Objective>>,
    onRegisterNewObjective: (text: string) => Promise<Objective>,
    editorMap: ActivityEditorMap, resourceContext: ResourceContext  }) => {

  const [isPopoverOpen, setIsPopoverOpen] = useState(false);

  const handleAdd = (editorDesc: EditorDesc) => {

    let model : ActivityModelSchema;
    let selectedObjectives : string[];

    promptForObjectiveSelection(objectives, childrenObjectives, onRegisterNewObjective)
    .then((objectives: string[]) => invokeCreationFunc(editorDesc.slug, resourceContext)
      .then((createdModel) => {

        model = createdModel;
        selectedObjectives = objectives;

        return Persistence.create(resourceContext.projectSlug, editorDesc.slug, model, objectives);
      })
      .then((result: Persistence.Created) => {

        const resourceContent : ActivityReference = {
          type: 'activity-reference',
          id: guid(),
          activitySlug: result.revisionSlug,
          purpose: 'none',
          children: [],
        };

        // For every part that we find in the model, we attach the selected
        // objectives to it
        const objectives = model.authoring.parts.map((p: any) => p.id)
          .reduce(
            (p: any, id: string) => {
              p[id] = selectedObjectives;
              return p;
            },
            {});

        const activity : Activity = {
          type: 'activity',
          activitySlug: result.revisionSlug,
          typeSlug: editorDesc.slug,
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

  const content =
    <div className="insert-item list-group-item list-group-item-action" key="content"
      onClick={() => onAddItem(createDefaultStructuredContent(), index)}>
      Content
    </div>;

  const activityEntries = Object
    .keys(editorMap)
    .map((k: string) => {
      const editorDesc : EditorDesc = editorMap[k];
      return (
        <div className="insert-item list-group-item list-group-item-action" key={editorDesc.slug}
            onClick={handleAdd.bind(this, editorDesc)}>
            {editorDesc.friendlyName}
        </div>
      );
    });

  const contentFn = () =>
      <div className="add-resource-popover-content">
        <div className="list-group">
          {[content, ...activityEntries]}
        </div>
      </div>;

  const [latestClickEvent, setLatestClickEvent] = useState<MouseEvent>();
  const togglePopover = (e: React.MouseEvent) => {
    setIsPopoverOpen(!isPopoverOpen);
    setLatestClickEvent(e.nativeEvent);
  };

  return (
      <div className={classNames(['add-resource-content', isPopoverOpen ? 'active' : '', isLast ? 'add-resource-content-last' : ''])}
        onClick={togglePopover}>

        {editMode &&
          <React.Fragment>
            <div className="insert-button-container">
              <Popover
                containerClassName="add-resource-popover"
                onClickOutside={(e) => {
                  if (e !== latestClickEvent) {
                    setIsPopoverOpen(false);
                  }
                }}
                isOpen={isPopoverOpen}
                align="start"
                transitionDuration={0.25}
                position={['bottom', 'top']}
                content={contentFn}>
                  {ref => <div ref={ref} className="insert-button">
                    <i className="fa fa-plus"></i>
                  </div>}
              </Popover>
            </div>
            <div className="insert-adornment"></div>

            {isLast && (
              <div className="insert-label mt-4 text-center">
                <button className="btn btn-sm btn-light">
                  Add Content or Activity
                </button>
              </div>
            )}
          </React.Fragment>
        }

      </div>
  );
};
