import * as Immutable from 'immutable';
import React from 'react';
import { PersistenceStrategy, PersistenceState } from 'data/persistence/PersistenceStrategy';
import { DeferredPersistenceStrategy } from 'data/persistence/DeferredPersistenceStrategy';
import { ActivityContext } from 'data/content/activity';
import { Objective } from 'data/content/objective';
import { TitleBar } from '../content/TitleBar';
import { UndoRedo } from '../content/UndoRedo';
import { ProjectSlug, ResourceSlug, ObjectiveSlug, ActivitySlug } from 'data/types';
import {
  UndoableState, processRedo, processUndo, processUpdate, init,
  registerUndoRedoHotkeys, unregisterUndoRedoHotkeys,
} from '../resource/undo';
import { releaseLock, acquireLock, NotAcquired } from 'data/persistence/lock';
import * as Persistence from 'data/persistence/activity';
import { ActivityModelSchema } from 'components/activities/types';
import { PersistenceStatus } from 'components/content/PersistenceStatus';
import { Message, createMessage, Severity } from 'data/messages/messages';
import { Banner } from '../messages/Banner';
import { PartObjectives } from 'components/activity/PartObjectives';
import { valueOr } from 'utils/common';
import { isFirefox } from 'utils/browser';

import './ActivityEditor.scss';

export interface ActivityEditorProps extends ActivityContext {

}

// This is the state of our activity editing that is undoable
type Undoable = {
  title: string,
  content: ActivityModelSchema,
  objectives: Immutable.Map<string, Immutable.List<ObjectiveSlug>>,
};

type ActivityEditorState = {
  messages: Message[],
  undoable: UndoableState<Undoable>,
  allObjectives: Immutable.List<Objective>,
  editMode: boolean,
  persistence: PersistenceState,
};

// Creates a function that when invoked submits a save request
function prepareSaveFn(
  project: ProjectSlug, resource: ResourceSlug,
  activity: ActivitySlug, update: Persistence.ActivityUpdate) {

  return (releaseLock: boolean) =>
    Persistence.edit(project, resource, activity, update, releaseLock);
}

function registerUnload(strategy: PersistenceStrategy) {
  return window.addEventListener('beforeunload', (event) => {

    if (isFirefox) {
      setTimeout(() => strategy.destroy());
    } else {
      strategy.destroy();
    }

  });
}


function unregisterUnload(listener: any) {
  window.removeEventListener('beforeunload', listener);
}

// The activity editor
export class ActivityEditor extends React.Component<ActivityEditorProps, ActivityEditorState> {

  persistence: PersistenceStrategy;
  windowUnloadListener: any;
  undoRedoListener: any;
  ref: any;

  constructor(props: ActivityEditorProps) {
    super(props);

    const { title, objectives, allObjectives, model } = props;

    const o = Object.keys(objectives).map(o => [o, objectives[o]]);

    this.state = {
      messages: [],
      editMode: true,
      undoable: init({
        title,
        objectives: Immutable.Map<string, Immutable.List<ObjectiveSlug>>(o as any),
        content: model,
      }),
      persistence: 'idle',
      allObjectives: Immutable.List<Objective>(allObjectives),
    };

    this.persistence = new DeferredPersistenceStrategy(500);

    this.update = this.update.bind(this);
    this.undo = this.undo.bind(this);
    this.redo = this.redo.bind(this);

    this.ref = React.createRef();
  }

  componentDidMount() {

    const { projectSlug, resourceSlug } = this.props;

    this.persistence.initialize(
      acquireLock.bind(undefined, projectSlug, resourceSlug),
      releaseLock.bind(undefined, projectSlug, resourceSlug),
      () => {},
      failure => this.publishErrorMessage(failure),
      persistence => this.setState({ persistence }),
    ).then((editMode) => {
      this.setState({ editMode });
      if (editMode) {
        this.windowUnloadListener = registerUnload(this.persistence);
        this.undoRedoListener = registerUndoRedoHotkeys(this.undo.bind(this), this.redo.bind(this));
      } else {
        if (this.persistence.getLockResult().type === 'not_acquired') {
          const notAcquired: NotAcquired = this.persistence.getLockResult() as NotAcquired;
          this.editingLockedMessage(notAcquired.user);
        }
      }
    });

    if (this.ref !== null) {
      this.ref.current.addEventListener('modelUpdated', (e : CustomEvent) => {
        e.preventDefault();
        e.stopPropagation();

        // Convert it back to using 'content', instead of 'model'
        this.update({ content: Object.assign({}, e.detail.model) });
      });
    }
  }

  componentWillUnmount() {
    this.persistence.destroy();
    if (this.windowUnloadListener !== null) {
      unregisterUnload(this.windowUnloadListener);
    }

    if (this.undoRedoListener !== null) {
      unregisterUndoRedoHotkeys(this.undoRedoListener);
    }
  }

  editingLockedMessage(email: string) {
    const message = createMessage({
      canUserDismiss: false,
      content: 'Read Only. User ' + email + ' is currently editing this page.',
      severity: Severity.Information,
    });
    this.setState({ messages: [...this.state.messages, message] });
  }

  publishErrorMessage(failure: any) {
    const message = createMessage({
      canUserDismiss: true,
      content: 'A problem occurred while saving your changes',
    });
    this.setState({ messages: [...this.state.messages, message] });
  }

  update(update: Partial<Undoable>) {

    const syncedUpdate = this.syncObjectivesWithParts(update);

    this.setState(
      { undoable: processUpdate(this.state.undoable, syncedUpdate) },
      () => this.save());
  }

  syncObjectivesWithParts(update: Partial<Undoable>) {

    if (update.content !== undefined) {

      let objectives = this.state.undoable.current.objectives;
      const parts = valueOr(update.content.authoring.parts, []);
      const partIds = parts.map((p: any) => valueOr(p.id, ''))
        .reduce((m: any, id: string) => { m[id] = true; return m; }, {});

      const keys = objectives.keySeq().toArray();
      keys.forEach((pId: string)  => {
        if (partIds[pId.toString()] === undefined) {
          objectives = objectives.delete(pId);
        }
      });

      return Object.assign({}, update, { objectives });

    }
    return update;
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

    const { authoringElement } = this.props;

    const onTitleEdit = (title: string) => {
      this.update({ title });
    };

    const onRegisterNewObjective = (o: Objective) => {
      this.setState({ allObjectives: this.state.allObjectives.concat(o) });
    };

    const webComponentProps = {
      model: JSON.stringify(this.state.undoable.current.content),
      editMode: this.state.editMode,
      projectSlug: this.props.projectSlug,
    };

    const parts = valueOr(this.state.undoable.current.content.authoring.parts, []);
    const partIds = parts.map((p: any) => p.id);

    return (
      <div className="col-12">
        <div className="activity-editor">
          <Banner
            dismissMessage={msg => this.setState(
              { messages: this.state.messages.filter(m => msg.guid !== m.guid) })}
            executeAction={() => true}
            messages={this.state.messages} />
          <TitleBar
            className="mb-4"
            title={this.state.undoable.current.title}
            onTitleEdit={onTitleEdit}
            editMode={this.state.editMode}>
            <PersistenceStatus persistence={this.state.persistence}/>
            <UndoRedo
              canRedo={this.state.undoable.redoStack.size > 0}
              canUndo={this.state.undoable.undoStack.size > 0}
              onUndo={this.undo} onRedo={this.redo}/>
          </TitleBar>
          <PartObjectives
              partIds={Immutable.List(partIds)}
              editMode={this.state.editMode}
              projectSlug={webComponentProps.projectSlug}
              objectives={this.state.undoable.current.objectives}
              allObjectives={this.state.allObjectives}
              onRegisterNewObjective={onRegisterNewObjective}
              onEdit={objectives => this.update({ objectives })} />
          <div ref={this.ref}>
            {React.createElement(authoringElement, webComponentProps as any)}
          </div>
        </div>
      </div>
    );
  }
}
