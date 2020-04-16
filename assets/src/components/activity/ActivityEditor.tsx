import * as Immutable from 'immutable';
import React from 'react';
import { PersistenceStrategy } from 'data/persistence/PersistenceStrategy';
import { DeferredPersistenceStrategy } from 'data/persistence/DeferredPersistenceStrategy';
import { ActivityContext, ObjectiveMap } from 'data/content/activity';
import { Objective } from 'data/content/objective';

import { Objectives } from '../resource/Objectives';
import { ProjectSlug, ResourceSlug, ObjectiveSlug, ActivitySlug } from 'data/types';
import { makeRequest } from 'data/persistence/common';
import { UndoableState, processRedo, processUndo, processUpdate, init } from '../resource/undo';
import { releaseLock, acquireLock } from 'data/persistence/lock';
import { ActivityModelSchema } from 'components/activities/types';

export interface ActivityEditorProps extends ActivityContext {

}

// This is the state of our activity editing that is undoable
type Undoable = {
  title: string,
  model: ActivityModelSchema,
  objectives: Immutable.Map<string, Immutable.List<ObjectiveSlug>>,
};

type ActivityEditorState = {
  undoable: UndoableState<Undoable>,
  allObjectives: Immutable.List<Objective>,
  editMode: boolean,
  persistence: 'idle' | 'pending' | 'inflight',
};

// Creates a function that when invoked submits a save request
function prepareSaveFn(
  project: ProjectSlug, resource: ResourceSlug, activity: ActivitySlug, body: any) {
  return () => {
    const params = {
      method: 'PUT',
      body: JSON.stringify({ update: body }),
      url: `/project/${project}/resource/${resource}/activity/${activity}`,
    };

    return makeRequest(params);
  };
}

function registerUnload(strategy: PersistenceStrategy) {
  return window.addEventListener('beforeunload', (event) => {
    strategy.destroy();
  });
}

function unregisterUnload(listener: any) {
  window.removeEventListener('beforeunload', listener);
}

// The activity editor
export class ActivityEditor extends React.Component<ActivityEditorProps, ActivityEditorState> {

  persistence: PersistenceStrategy;
  windowUnloadListener: any;

  constructor(props: ActivityEditorProps) {
    super(props);

    const { title, objectives, allObjectives, model } = props;

    const o = Object.keys(objectives).map(o => [o, objectives[o]]);

    this.state = {
      editMode: true,
      undoable: init({
        title,
        objectives: Immutable.Map<string, Immutable.List<ObjectiveSlug>>(o as any),
        model,
      }),
      persistence: 'idle',
      allObjectives: Immutable.List<Objective>(allObjectives),
    };

    this.persistence = new DeferredPersistenceStrategy();

    this.update = this.update.bind(this);
    this.undo = this.undo.bind(this);
    this.redo = this.redo.bind(this);

  }

  componentDidMount() {

    const { projectSlug, resourceSlug } = this.props;

    this.persistence.initialize(
      acquireLock.bind(undefined, projectSlug, resourceSlug),
      releaseLock.bind(undefined, projectSlug, resourceSlug),
      () => {},
      () => {},
      persistence => this.setState({ persistence }),
    ).then((editMode) => {
      this.setState({ editMode });
      if (editMode) {
        this.windowUnloadListener = registerUnload(this.persistence);
      }
    });
  }

  componentWillUnmount() {
    this.persistence.destroy();
    if (this.windowUnloadListener !== null) {
      unregisterUnload(this.windowUnloadListener);
    }
  }

  update(update: Partial<Undoable>) {
    this.setState(
      { undoable: processUpdate(this.state.undoable, update) },
      () => this.save());
  }

  save() {
    const { projectSlug, resourceSlug, activitySlug } = this.props;
    this.persistence.save(
      prepareSaveFn(projectSlug, resourceSlug, activitySlug, this.state.undoable.current));
  }

  undo() {
    this.setState({ undoable: processUndo(this.state.undoable) },
    () => this.save());
  }

  redo() {
    this.setState({ undoable: processRedo(this.state.undoable) },
    () => this.save());
  }

  render() {

    const { authoringElement, model } = this.props;
    const state = this.state;

    const onModelEdit = (model: ActivityModelSchema) => {
      this.update({ model });
    };

    const onTitleEdit = (title: string) => {
      this.update({ title });
    };

    const webComponentProps = {
      model: JSON.stringify(model),
    };

    return (
      <div>
        {React.createElement(authoringElement, webComponentProps as any)}
      </div>
    );
  }
}
