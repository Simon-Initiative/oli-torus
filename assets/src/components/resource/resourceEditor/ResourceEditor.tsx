import React from 'react';
import { connect } from 'react-redux';
import { State, Dispatch } from 'state';
import * as Immutable from 'immutable';
import { PersistenceStrategy } from 'data/persistence/PersistenceStrategy';
import { DeferredPersistenceStrategy } from 'data/persistence/DeferredPersistenceStrategy';
import {
  ResourceContent,
  ResourceContext,
  Activity,
  ActivityMap,
  createDefaultStructuredContent,
} from 'data/content/resource';
import { Objective } from 'data/content/objective';
import { ActivityEditorMap } from 'data/content/editors';
import { Editors } from '../editors/Editors';
import { TitleBar } from '../../content/TitleBar';
import { UndoRedo } from '../../content/UndoRedo';
import { PersistenceStatus } from 'components/content/PersistenceStatus';
import { ProjectSlug, ResourceSlug, ResourceId } from 'data/types';
import * as Persistence from 'data/persistence/resource';
import {
  UndoableState,
  processRedo,
  processUndo,
  processUpdate,
  init,
  registerUndoRedoHotkeys,
  unregisterUndoRedoHotkeys,
} from '../undo';
import { releaseLock, acquireLock, NotAcquired } from 'data/persistence/lock';
import { Message, Severity, createMessage } from 'data/messages/messages';
import { Banner } from '../../messages/Banner';
import { create } from 'data/persistence/objective';
import {
  registerUnload,
  registerKeydown,
  registerKeyup,
  registerWindowBlur,
  unregisterUnload,
  unregisterKeydown,
  unregisterKeyup,
  unregisterWindowBlur,
} from './listeners';
import { loadPreferences } from 'state/preferences';
import guid from 'utils/guid';
import './ResourceEditor.scss';

export interface ResourceEditorProps extends ResourceContext {
  editorMap: ActivityEditorMap; // Map of activity types to activity elements
  activities: ActivityMap;
  onLoadPreferences: () => void;
}

// This is the state of our resource that is undoable
type Undoable = {
  title: string;
  content: Immutable.OrderedMap<string, ResourceContent>;
  objectives: Immutable.List<ResourceId>;
};

type ResourceEditorState = {
  messages: Message[];
  undoable: UndoableState<Undoable>;
  allObjectives: Immutable.List<Objective>;
  childrenObjectives: Immutable.Map<ResourceId, Immutable.List<Objective>>;
  activities: Immutable.Map<string, Activity>;
  editMode: boolean;
  persistence: 'idle' | 'pending' | 'inflight';
  metaModifier: boolean;
};

// Creates a function that when invoked submits a save request
function prepareSaveFn(
  project: ProjectSlug,
  resource: ResourceSlug,
  update: Persistence.ResourceUpdate,
) {
  return (releaseLock: boolean) => Persistence.edit(project, resource, update, releaseLock);
}

// Ensures that there is some default content if the initial content
// of this resource is empty
function withDefaultContent(content: ResourceContent[]): [string, ResourceContent][] {
  if (content.length > 0) {
    return content.map((contentItem) => {
      // There is the possibility that ingested course material did not specify the
      // id attribute. If so, we will assign one here that will get persisted once the user
      // edits the page.
      contentItem =
        contentItem.id === undefined ? Object.assign({}, contentItem, { id: guid() }) : contentItem;
      return [contentItem.id, contentItem];
    });
  }
  const defaultContent = createDefaultStructuredContent();
  return [[defaultContent.id, defaultContent]];
}

function mapChildrenObjectives(
  objectives: Objective[],
): Immutable.Map<ResourceId, Immutable.List<Objective>> {
  return objectives.reduce((map, o) => {
    if (o.parentId !== null) {
      let updatedMap = map;
      if (o.parentId !== null && !map.has(o.parentId)) {
        updatedMap = updatedMap.set(o.parentId, Immutable.List());
      }
      const appended = (updatedMap.get(o.parentId) as any).push(o);
      return updatedMap.set(o.parentId, appended);
    }
    return map;
  }, Immutable.Map<ResourceId, Immutable.List<Objective>>());
}

// The resource editor
export class ResourceEditor extends React.Component<ResourceEditorProps, ResourceEditorState> {
  persistence: PersistenceStrategy;
  windowUnloadListener: any;
  undoRedoListener: any;
  keydownListener: any;
  keyupListener: any;
  mousedownListener: any;
  mouseupListener: any;
  windowBlurListener: any;

  constructor(props: ResourceEditorProps) {
    super(props);

    const { title, objectives, allObjectives, content, activities } = props;

    this.state = {
      messages: [],
      editMode: true,
      undoable: init({
        title,
        objectives: Immutable.List<ResourceId>(objectives.attached),
        content: Immutable.OrderedMap<string, ResourceContent>(withDefaultContent(content.model)),
      }),
      persistence: 'idle',
      allObjectives: Immutable.List<Objective>(allObjectives),
      childrenObjectives: mapChildrenObjectives(allObjectives),
      activities: Immutable.Map<string, Activity>(
        Object.keys(activities).map((k) => [k, activities[k]]),
      ),
      metaModifier: false,
    };

    this.persistence = new DeferredPersistenceStrategy();

    this.update = this.update.bind(this);
    this.undo = this.undo.bind(this);
    this.redo = this.redo.bind(this);
  }

  componentDidMount() {
    const { projectSlug, resourceSlug, onLoadPreferences } = this.props;

    onLoadPreferences();

    this.persistence
      .initialize(
        acquireLock.bind(undefined, projectSlug, resourceSlug),
        releaseLock.bind(undefined, projectSlug, resourceSlug),
        // eslint-disable-next-line
        () => {},
        (failure) => this.publishErrorMessage(failure),
        (persistence) => this.setState({ persistence }),
      )
      .then((editMode) => {
        this.setState({ editMode });
        if (editMode) {
          this.windowUnloadListener = registerUnload(this.persistence);
          this.undoRedoListener = registerUndoRedoHotkeys(
            this.undo.bind(this),
            this.redo.bind(this),
          );
          this.keydownListener = registerKeydown(this);
          this.keyupListener = registerKeyup(this);
          this.windowBlurListener = registerWindowBlur(this);
        } else {
          if (this.persistence.getLockResult().type === 'not_acquired') {
            const notAcquired: NotAcquired = this.persistence.getLockResult() as NotAcquired;
            this.editingLockedMessage(notAcquired.user);
          }
        }
      });
  }

  componentWillUnmount() {
    this.persistence.destroy();

    unregisterUnload(this.windowUnloadListener);
    unregisterUndoRedoHotkeys(this.undoRedoListener);
    unregisterKeydown(this.keydownListener);
    unregisterKeyup(this.keyupListener);
    unregisterWindowBlur(this.windowBlurListener);
  }

  editingLockedMessage(email: string) {
    const message = createMessage({
      guid: 'readonly-error',
      canUserDismiss: false,
      content: 'Read Only. User ' + email + ' is currently editing this page.',
      severity: Severity.Information,
    });
    this.addAsUnique(message);
  }

  publishErrorMessage(failure: any) {
    let message;
    switch (failure?.status) {
      case 423:
        message = 'refresh the page to re-gain edit access.';
        break;
      case 404:
        message = 'this page was not found. Try reopening it from the Curriculum.';
        break;
      case 403:
        message = "you're not able to access this page. Did your login expire?";
        break;
      case 500:
      default:
        message =
          // tslint:disable-next-line
          'there was a general problem on our end. Please try refreshing the page and trying again.';
        break;
    }

    this.addAsUnique(
      createMessage({
        guid: 'general-error',
        canUserDismiss: true,
        content: "Your changes weren't saved: " + message,
      }),
    );
  }

  createObjectiveErrorMessage(failure: any) {
    const message = createMessage({
      guid: 'objective-error',
      canUserDismiss: true,
      content: 'A problem occurred while creating your new objective',
      severity: Severity.Error,
    });
    this.addAsUnique(message);
  }

  addAsUnique(message: Message) {
    const messages = this.state.messages.filter((m) => m.guid !== message.guid);
    this.setState({ messages: [...messages, message] });
  }

  update(update: Partial<Undoable>) {
    this.setState({ undoable: processUpdate(this.state.undoable, update) }, () => this.save());
  }

  save() {
    const { projectSlug, resourceSlug } = this.props;

    const toSave: Persistence.ResourceUpdate = {
      objectives: { attached: this.state.undoable.current.objectives.toArray() },
      title: this.state.undoable.current.title,
      content: { model: this.state.undoable.current.content.toArray().map(([k, v]) => v) },
      releaseLock: false,
    };

    this.persistence.save(prepareSaveFn(projectSlug, resourceSlug, toSave));
  }

  undo() {
    this.setState({ undoable: processUndo(this.state.undoable) }, () => this.save());
  }

  redo() {
    this.setState({ undoable: processRedo(this.state.undoable) }, () => this.save());
  }

  render() {
    const props = this.props;
    const state = this.state;

    const { projectSlug, resourceSlug } = this.props;

    const onEdit = (content: Immutable.OrderedMap<string, ResourceContent>) => {
      this.update({ content });
    };

    const onTitleEdit = (title: string) => {
      this.update({ title });
    };

    const onAddItem = (c: ResourceContent, index: number, a?: Activity) => {
      this.update({
        content: this.state.undoable.current.content
          .take(index)
          .concat([[c.id, c]])
          .concat(this.state.undoable.current.content.skip(index)),
      });
      if (a) {
        this.setState({ activities: this.state.activities.set(a.activitySlug, a) });
      }
    };

    const onRegisterNewObjective = (title: string): Promise<Objective> => {
      return new Promise((resolve, reject) => {
        create(props.projectSlug, title)
          .then((result) => {
            if (result.result === 'success') {
              const objective = {
                id: result.resourceId,
                title,
                parentId: null,
              };

              this.setState({
                allObjectives: this.state.allObjectives.push(objective),
                childrenObjectives: this.state.childrenObjectives.set(
                  objective.id,
                  Immutable.List<Objective>(),
                ),
              });

              resolve(objective);
            } else {
              throw result;
            }
          })
          .catch((e) => {
            this.createObjectiveErrorMessage(e);
            console.error('objective creation failed', e);
          });
      });
    };

    const isSaving = this.state.persistence === 'inflight' || this.state.persistence === 'pending';

    const PreviewButton = () => (
      <a
        className={`btn btn-sm btn-outline-primary ml-3 ${isSaving ? 'disabled' : ''}`}
        onClick={() =>
          window.open(
            `/authoring/project/${projectSlug}/preview/${resourceSlug}`,
            `preview-${projectSlug}`,
          )
        }
      >
        Preview <i className="las la-external-link-alt ml-1"></i>
      </a>
    );

    return (
      <div className="resource-editor row">
        <div className="col-12">
          <Banner
            dismissMessage={(msg) =>
              this.setState({ messages: this.state.messages.filter((m) => msg.guid !== m.guid) })
            }
            executeAction={(message, action) => action.execute(message)}
            messages={this.state.messages}
          />
          <TitleBar
            title={state.undoable.current.title}
            onTitleEdit={onTitleEdit}
            editMode={this.state.editMode}
          >
            <PersistenceStatus persistence={this.state.persistence} />

            <PreviewButton />

            <UndoRedo
              canRedo={this.state.undoable.redoStack.size > 0}
              canUndo={this.state.undoable.undoStack.size > 0}
              onUndo={this.undo}
              onRedo={this.redo}
            />
          </TitleBar>
          <div>
            <Editors
              {...props}
              editMode={this.state.editMode}
              objectives={this.state.allObjectives}
              childrenObjectives={this.state.childrenObjectives}
              onRegisterNewObjective={onRegisterNewObjective}
              activities={this.state.activities}
              onRemove={(key) => onEdit(this.state.undoable.current.content.delete(key))}
              onEdit={(c, key) => onEdit(this.state.undoable.current.content.set(key, c))}
              onEditContentList={onEdit}
              content={this.state.undoable.current.content}
              onAddItem={onAddItem}
              resourceContext={props}
            />
          </div>
        </div>
      </div>
    );
  }
}

// eslint-disable-next-line
interface StateProps {}

interface DispatchProps {
  onLoadPreferences: () => void;
}

type OwnProps = {
  editorMap: ActivityEditorMap;
  activities: ActivityMap;
};

const mapStateToProps = (state: State, ownProps: OwnProps): StateProps => {
  return {};
};

const mapDispatchToProps = (dispatch: Dispatch, ownProps: OwnProps): DispatchProps => {
  return {
    onLoadPreferences: () => dispatch(loadPreferences()),
  };
};

export default connect<StateProps, DispatchProps, OwnProps>(
  mapStateToProps,
  mapDispatchToProps,
)(ResourceEditor);
