import { MultiInputSchema } from 'components/activities/multi_input/schema';
import { guaranteeMultiInputValidity } from 'components/activities/multi_input/utils';
import { ActivityModelSchema, Undoable as ActivityUndoable } from 'components/activities/types';
import { EditorUpdate as ActivityEditorUpdate } from 'components/activity/InlineActivityEditor';
import { PersistenceStatus } from 'components/content/PersistenceStatus';
import { TitleBar } from 'components/content/TitleBar';
import { Banner } from 'components/messages/Banner';
import { Editors } from 'components/resource/editors/Editors';
import { Objectives } from 'components/resource/objectives/Objectives';
import { ObjectivesSelection } from 'components/resource/objectives/ObjectivesSelection';
import { UndoToasts } from 'components/resource/undo/UndoToasts';
import { ActivityEditContext } from 'data/content/activity';
import { guaranteeValididty } from 'data/content/bank';
import { ActivityEditorMap } from 'data/content/editors';
import { Objective } from 'data/content/objective';
import {
  ActivityMap,
  ActivityReference,
  createDefaultStructuredContent,
  ResourceContent,
  ResourceContext,
  StructuredContent,
} from 'data/content/resource';
import { Tag } from 'data/content/tags';
import { createMessage, Message, Severity } from 'data/messages/messages';
import * as ActivityPersistence from 'data/persistence/activity';
import { DeferredPersistenceStrategy } from 'data/persistence/DeferredPersistenceStrategy';
import { acquireLock, NotAcquired, releaseLock } from 'data/persistence/lock';
import { PersistenceStrategy } from 'data/persistence/PersistenceStrategy';
import * as Persistence from 'data/persistence/resource';
import { ProjectSlug, ResourceId, ResourceSlug } from 'data/types';
import * as Immutable from 'immutable';
import React from 'react';
import { connect } from 'react-redux';
import { Dispatch, State } from 'state';
import { loadPreferences } from 'state/preferences';
import guid from 'utils/guid';
import { Operations } from 'utils/pathOperations';
import { registerUnload, unregisterUnload } from './listeners';
import './PageEditor.scss';
import { empty, PageUndoable, Undoables } from './types';

export interface PageEditorProps extends ResourceContext {
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

type PageEditorState = {
  messages: Message[];
  title: string;
  content: Immutable.OrderedMap<string, ResourceContent>;
  activityContexts: Immutable.OrderedMap<string, ActivityEditContext>;
  objectives: Immutable.List<ResourceId>;
  allObjectives: Immutable.List<Objective>;
  allTags: Immutable.List<Tag>;
  childrenObjectives: Immutable.Map<ResourceId, Immutable.List<Objective>>;
  editMode: boolean;
  persistence: 'idle' | 'pending' | 'inflight';
  undoables: Undoables;
};

// Creates a function that when invoked submits a save request
function prepareSaveFn(
  project: ProjectSlug,
  resource: ResourceSlug,
  update: Persistence.ResourceUpdate,
) {
  return (releaseLock: boolean) =>
    Persistence.edit(project, resource, update, releaseLock).then((result) => {
      // check if the slug has changed as a result of the edit and reload the page if it has
      if (result.type === 'success' && result.revision_slug !== resource) {
        window.location.replace(`/authoring/project/${project}/resource/${result.revision_slug}`);
        return result;
      }
      return result;
    });
}

// Ensures that there is some default content if the initial content
// of this resource is empty
function withDefaultContent(
  content: (StructuredContent | ActivityReference)[],
): [string, ResourceContent][] {
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
export class PageEditor extends React.Component<PageEditorProps, PageEditorState> {
  persistence: PersistenceStrategy;
  activityPersistence: { [id: string]: PersistenceStrategy };
  windowUnloadListener: any;
  undoRedoListener: any;
  keydownListener: any;
  keyupListener: any;
  mousedownListener: any;
  mouseupListener: any;
  windowBlurListener: any;

  constructor(props: PageEditorProps) {
    super(props);

    const { title, objectives, allObjectives, content, allTags } = props;

    const activityContexts = Immutable.OrderedMap<string, ActivityEditContext>(
      this.props.activityContexts.map((c) => {
        return [c.activitySlug, c];
      }),
    );

    this.state = {
      activityContexts,
      messages: [],
      editMode: false,
      title,
      allTags: Immutable.List<Tag>(allTags),
      objectives: Immutable.List<ResourceId>(objectives.attached),
      content: Immutable.OrderedMap<string, ResourceContent>(
        withDefaultContent(content.model as any),
      ),
      persistence: 'idle',
      allObjectives: Immutable.List<Objective>(allObjectives),
      childrenObjectives: mapChildrenObjectives(allObjectives),
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
        } else if (this.persistence.getLockResult().type === 'not_acquired') {
          const notAcquired: NotAcquired = this.persistence.getLockResult() as NotAcquired;
          this.editingLockedMessage(notAcquired.user);
        }
      });

    if (window.location.hash !== '') {
      const e = document.getElementById(window.location.hash.substr(1));
      if (e !== null) {
        e.scrollIntoView();
      }
    }
  }

  componentWillUnmount() {
    this.persistence.destroy();

    unregisterUnload(this.windowUnloadListener);
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
    const model = this.adjustActivityForConstraints(
      this.state.activityContexts.get(key)?.typeSlug,
      update.content,
    );
    const withModel = {
      model: update.content,
      title: update.title,
      objectives: update.objectives,
      tags: update.tags,
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
          { ...update, content: model },
          releaseLock,
        );

      this.activityPersistence[key].save(saveFn);
    });
  }

  onRemove(key: string) {
    const item = this.state.content.get(key);
    const index = this.state.content.toArray().findIndex(([k, _item]) => k === key);

    if (item !== undefined) {
      const undoable: PageUndoable = {
        type: 'PageUndoable',
        description: 'Removed ' + (item.type === 'content' ? 'Content' : 'Activity'),
        index,
        item,
      };

      // If what we are removing is an activity reference, we need to flush any
      // pending saves to force the server to see the addition of this activity,
      // in the case where this removal hits in the same deferred persistence
      // window.
      if (item.type === 'activity-reference') {
        this.persistence.flushPendingChanges(false);
      }

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
          Operations.applyAll(model as any, item.undoable.operations);

          // Now save the change and push it down to the activity editor
          this.onActivityEdit(item.contentKey, {
            content: model,
            title: context.title,
            objectives: context.objectives,
            tags: context.tags,
          });
        }
      }
    }

    this.setState({ undoables: this.state.undoables.delete(guid) });
  }

  createObjectiveErrorMessage(_failure: any) {
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

  updateImmediate(update: Partial<EditorUpdate>) {
    const mergedState = Object.assign({}, this.state, update);
    this.setState(mergedState, () => this.saveImmediate());
  }

  // Makes any modifications necessary to adhere to a set of constraints that the server
  // uses to define "valid page content"
  //
  // The only adjustment made currently is to manipulate bank selections to ensure that they will be
  // valid queries.
  //
  // Adjustments are made in a way that does not push down the results back to the component
  // tree as updated props, rather, they are made inline just prior to scheduling an update
  // of content to be saved.  In this manner, we allow the user interface to display invalid, intermediate
  // states (as the user is creating a selection, for instance) that will always be saved
  // as valid states.
  adjustContentForConstraints(
    content: Immutable.OrderedMap<string, ResourceContent>,
  ): ResourceContent[] {
    const arr = content.toArray();

    return arr.map((v: any) => {
      const e = v[1];
      if (e.type === 'selection') {
        return Object.assign({}, e, { logic: guaranteeValididty(e.logic) });
      }
      return e;
    });
  }

  adjustActivityForConstraints(
    activityType: string | undefined,
    model: ActivityModelSchema,
  ): ActivityModelSchema {
    if (activityType === 'oli_multi_input') {
      return guaranteeMultiInputValidity(model as MultiInputSchema);
    }
    return model;
  }

  save() {
    const { projectSlug, resourceSlug } = this.props;

    const model = this.adjustContentForConstraints(this.state.content);

    const toSave: Persistence.ResourceUpdate = {
      objectives: { attached: this.state.objectives.toArray() },
      title: this.state.title,
      content: { model },
      releaseLock: false,
    };

    this.persistence.save(prepareSaveFn(projectSlug, resourceSlug, toSave));
  }

  saveImmediate() {
    const { projectSlug, resourceSlug } = this.props;

    const toSave: Persistence.ResourceUpdate = {
      objectives: { attached: this.state.objectives.toArray() },
      title: this.state.title,
      content: { model: this.state.content.toArray().map(([_k, v]) => v) },
      releaseLock: false,
    };

    this.persistence.saveImmediate(prepareSaveFn(projectSlug, resourceSlug, toSave));
  }

  render() {
    const props = this.props;
    const state = this.state;

    const { projectSlug, resourceSlug } = this.props;

    const onEdit = (content: Immutable.OrderedMap<string, ResourceContent>) => {
      this.update({ content });
    };

    const onTitleEdit = (title: string) => {
      this.updateImmediate({ title });
    };

    const onAddItem = (
      c: StructuredContent | ActivityReference,
      index: number,
      a?: ActivityEditContext,
    ) => {
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

    const onRegisterNewTag = (tag: Tag) => {
      this.setState({
        allTags: this.state.allTags.push(tag),
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
      <React.StrictMode>
        <div className="resource-editor row">
          <div className="col-12">
            <UndoToasts undoables={this.state.undoables} onInvokeUndo={this.onInvokeUndo} />

            <Banner
              dismissMessage={(msg: any) =>
                this.setState({ messages: this.state.messages.filter((m) => msg.guid !== m.guid) })
              }
              executeAction={(message: any, action: any) => action.execute(message)}
              messages={this.state.messages}
            />
            <TitleBar title={state.title} onTitleEdit={onTitleEdit} editMode={this.state.editMode}>
              <PersistenceStatus persistence={this.state.persistence} />

              <PreviewButton />
            </TitleBar>
            <Objectives>
              <ObjectivesSelection
                editMode={this.state.editMode}
                projectSlug={this.props.projectSlug}
                objectives={this.state.allObjectives.toArray()}
                selected={this.state.objectives.toArray()}
                onEdit={(objectives) => this.update({ objectives: Immutable.List(objectives) })}
                onRegisterNewObjective={onRegisterNewObjective}
              />
            </Objectives>

            <div>
              <Editors
                {...props}
                editMode={this.state.editMode}
                objectives={this.state.allObjectives}
                allTags={this.state.allTags}
                childrenObjectives={this.state.childrenObjectives}
                onRegisterNewObjective={onRegisterNewObjective}
                onRegisterNewTag={onRegisterNewTag}
                activityContexts={this.state.activityContexts}
                onRemove={(key: string) => this.onRemove(key)}
                onEdit={(c: any, key: string) => onEdit(this.state.content.set(key, c))}
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
      </React.StrictMode>
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

const mapStateToProps = (_state: State, _ownProps: OwnProps): StateProps => {
  return {};
};

const mapDispatchToProps = (dispatch: Dispatch, _ownProps: OwnProps): DispatchProps => {
  return {
    onLoadPreferences: () => dispatch(loadPreferences()),
  };
};

export default connect<StateProps, DispatchProps, OwnProps>(
  mapStateToProps,
  mapDispatchToProps,
)(PageEditor);
