import * as Immutable from 'immutable';
import React from 'react';
import { PersistenceStrategy } from 'data/persistence/PersistenceStrategy';
import { DeferredPersistenceStrategy } from 'data/persistence/DeferredPersistenceStrategy';
import { ResourceContent, ResourceContext,
  Activity, ActivityMap, createDefaultStructuredContent } from 'data/content/resource';
import { Objective } from 'data/content/objective';
import { ActivityEditorMap } from 'data/content/editors';
import { Editors } from './Editors';
import { TitleBar } from '../content/TitleBar';
import { UndoRedo } from '../content/UndoRedo';
import { PersistenceStatus } from 'components/content/PersistenceStatus';
import { ProjectSlug, ResourceSlug, ObjectiveSlug } from 'data/types';
import * as Persistence from 'data/persistence/resource';
import {
  UndoableState, processRedo, processUndo, processUpdate, init,
  registerUndoRedoHotkeys, unregisterUndoRedoHotkeys,
} from './undo';
import { releaseLock, acquireLock } from 'data/persistence/lock';
import { Message, createMessage } from 'data/messages/messages';
import { Banner } from '../messages/Banner';
import { BreadcrumbTrail } from 'components/common/BreadcrumbTrail';
import { create } from 'data/persistence/objective';

export interface ResourceEditorProps extends ResourceContext {
  editorMap: ActivityEditorMap;   // Map of activity types to activity elements
  activities: ActivityMap;
}

// This is the state of our resource that is undoable
type Undoable = {
  title: string,
  content: Immutable.List<ResourceContent>,
  objectives: Immutable.List<ObjectiveSlug>,
};

type ResourceEditorState = {
  messages: Message[],
  undoable: UndoableState<Undoable>,
  allObjectives: Immutable.List<Objective>,
  childrenObjectives: Immutable.Map<ObjectiveSlug, Immutable.List<Objective>>,
  activities: Immutable.Map<string, Activity>,
  editMode: boolean,
  persistence: 'idle' | 'pending' | 'inflight',
  previewMode: boolean,
  previewHtml: string,
};

// Creates a function that when invoked submits a save request
function prepareSaveFn(
  project: ProjectSlug, resource: ResourceSlug, update: Persistence.ResourceUpdate) {

  return () => Persistence.edit(project, resource, update);
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

function mapChildrenObjectives(objectives: Objective[])
  : Immutable.Map<ObjectiveSlug, Immutable.List<Objective>> {

  return objectives.reduce(
    (map, o) => {
      if (o.parentSlug !== null) {
        let updatedMap = map;
        if (o.parentSlug !== null && !map.has(o.parentSlug)) {
          updatedMap = updatedMap.set(o.parentSlug, Immutable.List());
        }
        const appended = (updatedMap.get(o.parentSlug) as any).push(o);
        return updatedMap.set(o.parentSlug, appended);
      }
      return map;
    },
    Immutable.Map<ObjectiveSlug, Immutable.List<Objective>>(),
  );
}

// The resource editor
export class ResourceEditor extends React.Component<ResourceEditorProps, ResourceEditorState> {

  persistence: PersistenceStrategy;
  windowUnloadListener: any;
  undoRedoListener: any;

  constructor(props: ResourceEditorProps) {
    super(props);

    const { title, objectives, allObjectives, content, activities } = props;

    this.state = {
      messages: [],
      editMode: true,
      undoable: init({
        title,
        objectives: Immutable.List<ObjectiveSlug>(objectives.attached),
        content: Immutable.List<ResourceContent>(withDefaultContent(content.model)),
      }),
      persistence: 'idle',
      allObjectives: Immutable.List<Objective>(allObjectives),
      childrenObjectives: mapChildrenObjectives(allObjectives),
      activities: Immutable.Map<string, Activity>(
        Object.keys(activities).map(k => [k, activities[k]])),
      previewMode: false,
      previewHtml: '',
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
      failure => this.publishErrorMessage(failure),
      persistence => this.setState({ persistence }),
    ).then((editMode) => {
      this.setState({ editMode });
      if (editMode) {
        this.windowUnloadListener = registerUnload(this.persistence);
        this.undoRedoListener = registerUndoRedoHotkeys(this.undo.bind(this), this.redo.bind(this));
      }
    });
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

  publishErrorMessage(failure: any) {
    const message = createMessage({
      canUserDismiss: true,
      content: 'A problem occurred while saving your changes',
    });
    this.setState({ messages: [...this.state.messages, message] });
  }

  update(update: Partial<Undoable>) {
    this.setState(
      { undoable: processUpdate(this.state.undoable, update) },
      () => this.save());
  }

  save() {
    const { projectSlug, resourceSlug } = this.props;

    const toSave : Persistence.ResourceUpdate = {
      objectives: { attached: this.state.undoable.current.objectives.toArray() },
      title: this.state.undoable.current.title,
      content: { model: this.state.undoable.current.content.toArray() },
    };

    this.persistence.save(
      prepareSaveFn(projectSlug, resourceSlug, toSave));
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

    const { projectSlug, resourceSlug, title } = this.props;
    const page = {
      slug: resourceSlug,
      title,
    };

    const onEdit = (content: Immutable.List<ResourceContent>) => {
      this.update({ content });
    };

    const onTitleEdit = (title: string) => {
      this.update({ title });
    };

    const onAddItem = (c : ResourceContent, index: number, a? : Activity) => {
      this.update({ content: this.state.undoable.current.content.insert(index, c) });
      if (a) {
        this.setState({ activities: this.state.activities.set(a.activitySlug, a) });
      }
    };

    const onRegisterNewObjective = (title: string) : Promise<Objective> => {
      return new Promise((resolve, reject) => {

        create(props.projectSlug, title)
        .then((result) => {
          if (result.type === 'success') {

            const objective = {
              slug: result.revisionSlug,
              title,
              parentSlug: null,
            };

            this.setState({
              allObjectives: this.state.allObjectives.push(objective),
              childrenObjectives:
                this.state.childrenObjectives.set(objective.slug, Immutable.List<Objective>()),
            });

            resolve(objective);

          } else {
            throw result;
          }
        })
        .catch((e) => {
          // TODO: this should probably give a message to the user indicating that
          // objective creation failed once we have a global messaging
          // infrastructure in place. For now, we will just log to the conosle
          console.error('objective creation failed', e);
        });

      });
    };

    const onPreviewClick = () => {
      const enteringPreviewMode = !state.previewMode;
      this.setState({ previewMode: !state.previewMode, previewHtml: '' });

      // window.open(`/project/${projectSlug}/resource/${resourceSlug}/preview`, 'page-preview')

      if (enteringPreviewMode) {
        fetch(`/project/${projectSlug}/resource/${resourceSlug}/preview`)
        .then((res) => {
          if (res.ok) {
            return res.text();
          }
        })
        .then((html) => {
          if (html) {
            this.setState({ previewHtml: html });
          }
        })
      }
    };

    const isSaving = (this.state.persistence === 'inflight' || this.state.persistence === 'pending');

    if (state.previewMode) {
      return (
        <div className="row">
          <div className="col-12 d-flex flex-column">
            <Banner
              dismissMessage={msg => this.setState(
                { messages: this.state.messages.filter(m => msg.guid !== m.guid) })}
              executeAction={() => true}
              messages={this.state.messages}
            />
            <BreadcrumbTrail projectSlug={projectSlug} page={page} />
            <div className="d-flex flex-row my-2">
              <div className="flex-grow-1"></div>
              <button
                role="button"
                className="btn btn-sm btn-warning"
                onClick={onPreviewClick}
                disabled={isSaving}>
                Exit Preview
              </button>
            </div>
            <div
              className="preview-content delivery flex-grow-1"
              dangerouslySetInnerHTML={{ __html: state.previewHtml }}
              ref={(div) => {
                // when this div is rendered and contains rendered preview html,
                // find and execute all scripts required to run the delivery elements
                if (div && state.previewHtml !== '') {
                  const scripts = div.getElementsByTagName('script')
                  for (let s of scripts) {
                    if (s.innerText) {
                      window.eval(s.innerText);
                    }
                  }
                }
              }}
              />
          </div>
        </div>
      )
    }

    return (
      <div className="row">
        <div className="col-12">
          <Banner
            dismissMessage={msg => this.setState(
              { messages: this.state.messages.filter(m => msg.guid !== m.guid) })}
            executeAction={() => true}
            messages={this.state.messages}
          />
          <BreadcrumbTrail projectSlug={projectSlug} page={page} />
          <TitleBar
            title={state.undoable.current.title}
            onTitleEdit={onTitleEdit}
            editMode={this.state.editMode}>
            <PersistenceStatus persistence={this.state.persistence}/>

            <button
              role="button"
              className="btn btn-sm btn-outline-primary ml-3"
              onClick={onPreviewClick}
              disabled={isSaving}>
              Preview Page
            </button>

            <UndoRedo
              canRedo={this.state.undoable.redoStack.size > 0}
              canUndo={this.state.undoable.undoStack.size > 0}
              onUndo={this.undo} onRedo={this.redo}/>
          </TitleBar>
          <div>
            <Editors {...props} editMode={this.state.editMode}
              objectives={this.state.allObjectives}
              childrenObjectives={this.state.childrenObjectives}
              onRegisterNewObjective={onRegisterNewObjective}
              activities={this.state.activities}
              onRemove={index => onEdit(this.state.undoable.current.content.delete(index))}
              onEdit={(c, index) => {
                onEdit(this.state.undoable.current.content.set(index, c));
              }}
              onEditContentList={onEdit}
              content={this.state.undoable.current.content}
              onAddItem={onAddItem}
              resourceContext={props} />
          </div>
        </div>
      </div>
    );
  }
}
