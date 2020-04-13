import * as Immutable from 'immutable';
import React from 'react';
import { PersistenceStrategy } from 'data/persistence/PersistenceStrategy';
import { DeferredPersistenceStrategy } from 'data/persistence/DeferredPersistenceStrategy';
import { ResourceContent, ResourceType, createDefaultStructuredContent } from 'data/content/resource';
import { Objective } from 'data/content/objective';
import { ActivityEditorMap } from 'data/content/editors';
import { Editors } from './Editors';
import { Objectives } from './Objectives';
import { Outline } from './Outline';
import { TitleBar } from './TitleBar';
import { ProjectSlug, ResourceSlug, ObjectiveSlug } from 'data/types';
import { makeRequest } from 'data/persistence/common';
import { UndoableState, processRedo, processUndo, processUpdate, init } from './undo';
import { releaseLock, acquireLock } from 'data/persistence/lock';

export type ResourceEditorProps = {
  resourceType: ResourceType,     // Page or assessment?
  authorEmail: string,            // The current author
  projectSlug: ProjectSlug,       // The current project
  resourceSlug: ResourceSlug,     // The current resource
  title: string,                  // The title of the resource
  content: ResourceContent[],     // Content of the resource
  objectives: ObjectiveSlug[],        // Attached objectives
  allObjectives: Objective[],     // All objectives
  editorMap: ActivityEditorMap,   // Map of activity types to activity elements
};

// This is the state of our resource that is undoable
type Undoable = {
  title: string,
  content: Immutable.List<ResourceContent>,
  objectives: Immutable.List<ObjectiveSlug>,
};

type ResourceEditorState = {
  undoable: UndoableState<Undoable>,
  allObjectives: Immutable.List<Objective>,
  editMode: boolean,
  persistence: 'idle' | 'pending' | 'inflight',
};

// Creates a function that when invoked submits a save request
function prepareSaveFn(project: ProjectSlug, resource: ResourceSlug, body: any) {
  return () => {
    const params = {
      method: 'PUT',
      body: JSON.stringify({ update: body }),
      url: `/project/${project}/${resource}/edit`,
    };

    return makeRequest(params);
  };
}

// Ensures that there is some default content if the initial content
// of this resource is empty
function withDefaultContent(content: ResourceContent[]) {
  return content.length > 0
    ? content
    : [createDefaultStructuredContent()];
}


function registerUnload(strategy: PersistenceStrategy) {
  return window.addEventListener('beforeunload', (event) => {
    strategy.destroy();
  });
}

function unregisterUnload(listener: any) {
  window.removeEventListener('beforeunload', listener);
}

// The resource editor
export class ResourceEditor extends React.Component<ResourceEditorProps, ResourceEditorState> {

  persistence: PersistenceStrategy;
  windowUnloadListener: any;

  constructor(props: ResourceEditorProps) {
    super(props);

    const { title, objectives, allObjectives, content } = props;

    this.state = {
      editMode: true,
      undoable: init({
        title,
        objectives: Immutable.List<ObjectiveSlug>(objectives),
        content: Immutable.List<ResourceContent>(withDefaultContent(content)),
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
    const { projectSlug, resourceSlug } = this.props;
    this.persistence.save(
      prepareSaveFn(projectSlug, resourceSlug, this.state.undoable.current));
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

    const props = this.props;
    const state = this.state;

    const onEdit = (content: Immutable.List<ResourceContent>) => {
      this.update({ content });
    };

    const onTitleEdit = (title: string) => {
      this.update({ title });
    };

    const onAddItem = (c : ResourceContent) =>
      this.update({ content: this.state.undoable.current.content.push(c) });

    const editingImpl = state.undoable.current.content.size > 1
      ? (
          <div className="d-flex flex-row align-items-start">
            <Outline {...props} editMode={this.state.editMode}
              onEdit={c => onEdit(c)} content={state.undoable.current.content}/>
            <Editors {...props} editMode={this.state.editMode}
              onEdit={c => onEdit(c)} content={state.undoable.current.content}/>
          </div>
        )
      : (
          <div className="p-4">
            <Editors {...props} editMode={this.state.editMode}
              onEdit={c => onEdit(c)} content={state.undoable.current.content}/>
          </div>
        );


    return (
      <div>
        <TitleBar
          onUndo={this.undo}
          onRedo={this.redo}
          canUndo={state.undoable.undoStack.size > 0}
          canRedo={state.undoable.redoStack.size > 0}
          title={state.undoable.current.title}
          onTitleEdit={onTitleEdit}
          onAddItem={onAddItem}
          editMode={this.state.editMode}
          editorMap={this.props.editorMap}/>
        <Objectives
          editMode={this.state.editMode}
          selected={this.state.undoable.current.objectives}
          objectives={this.state.allObjectives}
          onEdit={objectives => this.update({ objectives })} />
        {editingImpl}
      </div>
    );
  }
}
