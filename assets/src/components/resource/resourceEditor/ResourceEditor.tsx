import React from 'react';
import { connect } from 'react-redux';
import { State, Dispatch } from 'state';
import * as Immutable from 'immutable';
import { EditorUpdate as ActivityEditorUpdate } from 'components/activity/InlineActivityEditor';
import { PersistenceStrategy } from 'data/persistence/PersistenceStrategy';
import { DeferredPersistenceStrategy } from 'data/persistence/DeferredPersistenceStrategy';
import {
  ResourceContent,
  ResourceContext,
  ActivityMap,
  createDefaultStructuredContent,
  StructuredContent,
  ActivityReference,
} from 'data/content/resource';
import { Objective } from 'data/content/objective';
import { ActivityEditorMap } from 'data/content/editors';
import { Editors } from '../editors/Editors';
import { TitleBar } from '../../content/TitleBar';
import { PersistenceStatus } from 'components/content/PersistenceStatus';
import { ProjectSlug, ResourceSlug, ResourceId } from 'data/types';
import * as Persistence from 'data/persistence/resource';
import * as ActivityPersistence from 'data/persistence/activity';
import { releaseLock, acquireLock, NotAcquired } from 'data/persistence/lock';
import { Message, Severity, createMessage } from 'data/messages/messages';
import { Banner } from '../../messages/Banner';
import { ActivityEditContext } from 'data/content/activity';
import { create } from 'data/persistence/objective';
import { Undoable as ActivityUndoable } from 'components/activities/types';
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
import { Undoables, empty, PageUndoable } from './types';
import { UndoToasts } from './UndoToasts';
import { applyOperations } from 'utils/undo';
import './ResourceEditor.scss';

export interface ResourceEditorProps extends ResourceContext {
  editorMap: ActivityEditorMap; // Map of activity types to activity elements
  activities: ActivityMap;
  onLoadPreferences: () => void;
}

// The changes that the editor can make
type EditorUpdate = {
  title: string;
  content: Immutable.OrderedMap<string, ResourceContent>;
  objectives: Immutable.List<ResourceId>;
};

type ResourceEditorState = {
  messages: Message[];
  title: string;
  content: Immutable.OrderedMap<string, ResourceContent>;
  activityContexts: Immutable.OrderedMap<string, ActivityEditContext>;
  objectives: Immutable.List<ResourceId>;
  allObjectives: Immutable.List<Objective>;
  childrenObjectives: Immutable.Map<ResourceId, Immutable.List<Objective>>;
  editMode: boolean;
  persistence: 'idle' | 'pending' | 'inflight';
  metaModifier: boolean;
  undoables: Undoables;
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
function withDefaultContent(content: (StructuredContent | ActivityReference)[]): [string, ResourceContent][] {
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
  activityPersistence: { [id: string]: PersistenceStrategy };
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

    const activityContexts = Immutable.OrderedMap<string, ActivityEditContext>(
      this.props.activityContexts.map((c) => {
        return [c.activitySlug, c];
      }),
    );

    this.state = {
      activityContexts,
      messages: [],
      editMode: true,
      title,
      objectives: Immutable.List<ResourceId>(objectives.attached),
      content: Immutable.OrderedMap<string, ResourceContent>(withDefaultContent(content.model as any)),
      persistence: 'idle',
      allObjectives: Immutable.List<Objective>(allObjectives),
      childrenObjectives: mapChildrenObjectives(allObjectives),
      metaModifier: false,
      undoables: empty(),
    };

    this.persistence = new DeferredPersistenceStrategy();

    this.update = this.update.bind(this);
    this.onActivityEdit = this.onActivityEdit.bind(this);
    this.onPostUndoable = this.onPostUndoable.bind(this);
    this.onInvokeUndo = this.onInvokeUndo.bind(this);
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
          this.initActivityPersistence();
          this.windowUnloadListener = registerUnload(this.persistence);
          this.keydownListener = registerKeydown(this);
          this.keyupListener = registerKeyup(this);
          this.windowBlurListener = registerWindowBlur(this);
        } else if (this.persistence.getLockResult().type === 'not_acquired') {
          const notAcquired: NotAcquired = this.persistence.getLockResult() as NotAcquired;
          this.editingLockedMessage(notAcquired.user);
        }
      });
  }

  componentWillUnmount() {
    this.persistence.destroy();

    unregisterUnload(this.windowUnloadListener);
    unregisterKeydown(this.keydownListener);
    unregisterKeyup(this.keyupListener);
    unregisterWindowBlur(this.windowBlurListener);
  }

  initActivityPersistence() {
    this.activityPersistence = Object.keys(this.state.activityContexts.toObject()).reduce(
      (map, key) => {
        const activity: ActivityEditContext = this.state.activityContexts.get(
          key,
        ) as ActivityEditContext;

        const persistence = new DeferredPersistenceStrategy();
        persistence.initialize(
          () => Promise.resolve({ type: 'acquired' }),
          () => Promise.resolve({ type: 'acquired' }),
          // eslint-disable-next-line
          () => {},
          (failure) => this.publishErrorMessage(failure),
          (persistence) => this.setState({ persistence }),
        );

        (map as any)[activity.activitySlug] = persistence;
        return map;
      },
      {},
    );
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

  onActivityEdit(key: string, update: ActivityEditorUpdate): void {
    const withModel = {
      title: update.title !== undefined ? update.title : undefined,
      model: update.content !== undefined ? update.content : undefined,
      objectives: update.objectives !== undefined ? update.objectives : undefined,
    };
    // apply the edit
    const merged = Object.assign({}, this.state.activityContexts.get(key), withModel);
    const activityContexts = this.state.activityContexts.set(key, merged);

    this.setState({ activityContexts }, () => {
      const saveFn = (releaseLock: boolean) =>
        ActivityPersistence.edit(
          this.props.projectSlug,
          this.props.resourceId,
          merged.activityId,
          update as any,
          releaseLock,
        );

      this.activityPersistence[key].save(saveFn);
    });
  }

  onRemove(key: string) {
    const item = this.state.content.get(key);
    const index = this.state.content.toArray().findIndex(([k, item]) => k === key);

    if (item !== undefined) {
      const undoable: PageUndoable = {
        type: 'PageUndoable',
        description: 'Removed ' + (item.type === 'content' ? 'Content' : 'Activity'),
        index,
        item,
      };

      const content = this.state.content.delete(key);
      this.update({ content });
      this.onPostUndoable(key, undoable);
    }
  }

  onPostUndoable(key: string, undoable: ActivityUndoable | PageUndoable) {
    const id = guid();
    this.setState(
      {
        undoables: this.state.undoables.set(id, {
          guid: id,
          contentKey: key,
          undoable,
        }),
      },
      () =>
        setTimeout(
          () =>
            this.setState({
              undoables: this.state.undoables.delete(id),
            }),
          5000,
        ),
    );
  }

  onInvokeUndo(guid: string) {
    const item = this.state.undoables.get(guid);

    if (item !== undefined) {
      if (item.undoable.type === 'PageUndoable') {
        const content = this.state.content.toArray();
        content.splice(item.undoable.index, 0, [item.contentKey, item.undoable.item]);
        this.update({ content: Immutable.OrderedMap<string, ResourceContent>(content) });
      } else {
        const context = this.state.activityContexts.get(item.contentKey);
        if (context !== undefined) {
          // Perform a deep copy
          const model = JSON.parse(JSON.stringify(context.model));

          // Apply the undo operations to the model
          applyOperations(model as any, item.undoable.operations);

          // Now save the change and push it down to the activity editor
          this.onActivityEdit(item.contentKey, {
            content: model,
            title: context.title,
            objectives: context.objectives,
          });
        }
      }
    }

    this.setState({ undoables: this.state.undoables.delete(guid) });
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

  update(update: Partial<EditorUpdate>) {
    const mergedState = Object.assign({}, this.state, update);
    this.setState(mergedState, () => this.save());
  }

  save() {
    const { projectSlug, resourceSlug } = this.props;

    const toSave: Persistence.ResourceUpdate = {
      objectives: { attached: this.state.objectives.toArray() },
      title: this.state.title,
      content: { model: this.state.content.toArray().map(([k, v]) => v) },
      releaseLock: false,
    };

    this.persistence.save(prepareSaveFn(projectSlug, resourceSlug, toSave));
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

    const onAddItem = (c: StructuredContent | ActivityReference, index: number, a?: ActivityEditContext) => {
      this.update({
        content: this.state.content
          .take(index)
          .concat([[c.id, c]])
          .concat(this.state.content.skip(index)),
      });
      if (a) {
        const persistence = new DeferredPersistenceStrategy();
        persistence.initialize(
          () => Promise.resolve({ type: 'acquired' }),
          () => Promise.resolve({ type: 'acquired' }),
          // eslint-disable-next-line
          () => {},
          (failure) => this.publishErrorMessage(failure),
          (persistence) => this.setState({ persistence }),
        );
        this.activityPersistence[a.activitySlug] = persistence;

        this.setState({ activityContexts: this.state.activityContexts.set(a.activitySlug, a) });
      }
    };

    const onRegisterNewObjective = (objective: Objective) => {
      this.setState({
        allObjectives: this.state.allObjectives.push(objective),
        childrenObjectives: this.state.childrenObjectives.set(
          objective.id,
          Immutable.List<Objective>(),
        ),
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
          <UndoToasts undoables={this.state.undoables} onInvokeUndo={this.onInvokeUndo} />

          <Banner
            dismissMessage={(msg) =>
              this.setState({ messages: this.state.messages.filter((m) => msg.guid !== m.guid) })
            }
            executeAction={(message, action) => action.execute(message)}
            messages={this.state.messages}
          />
          <TitleBar title={state.title} onTitleEdit={onTitleEdit} editMode={this.state.editMode}>
            <PersistenceStatus persistence={this.state.persistence} />

            <PreviewButton />
          </TitleBar>
          <div>
            <Editors
              {...props}
              editMode={this.state.editMode}
              objectives={this.state.allObjectives}
              childrenObjectives={this.state.childrenObjectives}
              onRegisterNewObjective={onRegisterNewObjective}
              activityContexts={this.state.activityContexts}
              onRemove={(key) => this.onRemove(key)}
              onEdit={(c, key) => onEdit(this.state.content.set(key, c))}
              onEditContentList={onEdit}
              onActivityEdit={this.onActivityEdit}
              onPostUndoable={this.onPostUndoable}
              content={this.state.content}
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
