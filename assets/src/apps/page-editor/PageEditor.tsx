import React from 'react';
import { connect } from 'react-redux';
import Appsignal from '@appsignal/javascript';
import * as Immutable from 'immutable';
import { Dispatch, State } from 'state';
import { MultiInputSchema } from 'components/activities/multi_input/schema';
import { guaranteeMultiInputValidity } from 'components/activities/multi_input/utils';
import { ActivityModelSchema, Undoable as ActivityUndoable } from 'components/activities/types';
import { EditorUpdate as ActivityEditorUpdate } from 'components/activity/InlineActivityEditor';
import { PersistenceStatus } from 'components/content/PersistenceStatus';
import { TitleBar } from 'components/content/TitleBar';
import { setDefaultEditor } from 'components/editing/markdown_editor/markdown_util';
import { AlternativesContextProvider } from 'components/hooks/useAlternatives';
import { Banner } from 'components/messages/Banner';
import { ContentOutline } from 'components/resource/editors/ContentOutline';
import { Editors } from 'components/resource/editors/Editors';
import { Objectives } from 'components/resource/objectives/Objectives';
import { ObjectivesSelection } from 'components/resource/objectives/ObjectivesSelection';
import { arrangeObjectives } from 'components/resource/objectives/sort';
import { UndoToasts } from 'components/resource/undo/UndoToasts';
import { ActivityEditContext } from 'data/content/activity';
import { guaranteeValididty } from 'data/content/bank';
import { ActivityEditorMap } from 'data/content/editors';
import { Objective } from 'data/content/objective';
import {
  ActivityMap,
  ActivityReference,
  EditorType,
  ResourceContent,
  ResourceContext,
  StructuredContent,
  getResourceContentName,
} from 'data/content/resource';
import { Tag } from 'data/content/tags';
import { Message, Severity, createMessage } from 'data/messages/messages';
import { DeferredPersistenceStrategy } from 'data/persistence/DeferredPersistenceStrategy';
import { PersistenceStrategy } from 'data/persistence/PersistenceStrategy';
import * as ActivityPersistence from 'data/persistence/activity';
import { NotAcquired, acquireLock, releaseLock } from 'data/persistence/lock';
import * as Persistence from 'data/persistence/resource';
import { ProjectSlug, ResourceId, ResourceSlug } from 'data/types';
import { loadPreferences } from 'state/preferences';
import guid from 'utils/guid';
import { Operations } from 'utils/pathOperations';
import { AppsignalContext, ErrorBoundary } from '../../components/common/ErrorBoundary';
import { PageEditorContent } from '../../data/editor/PageEditorContent';
import { initAppSignal } from '../../utils/appsignal';
import '../ResourceEditor.scss';
import { registerUnload, unregisterUnload } from './listeners';
import { FeatureFlags, PageUndoable, Undoables, empty } from './types';

export interface PageEditorProps extends ResourceContext {
  editorMap: ActivityEditorMap; // Map of activity types to activity elements
  activities: ActivityMap;
  featureFlags: FeatureFlags;
  appsignalKey: string | null;
  defaultEditor: EditorType;
  onLoadPreferences: () => void;
}

// The changes that the editor can make
type EditorUpdate = {
  title: string;
  content: PageEditorContent;
  objectives: Immutable.List<ResourceId>;
};

type PageEditorState = {
  messages: Message[];
  title: string;
  content: PageEditorContent;
  activityContexts: Immutable.OrderedMap<string, ActivityEditContext>;
  objectives: Immutable.List<ResourceId>;
  allObjectives: Immutable.List<Objective>;
  allTags: Immutable.List<Tag>;
  childrenObjectives: Immutable.Map<ResourceId, Immutable.List<Objective>>;
  editMode: boolean;
  persistence: 'idle' | 'pending' | 'inflight';
  undoables: Undoables;
  appsignal: Appsignal | null;
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
        if (window.location.pathname.startsWith('/authoring/project')) {
          window.location.replace(`/authoring/project/${project}/resource/${result.revision_slug}`);
        } else if (window.location.pathname.startsWith('/workspaces/course_author')) {
          window.location.replace(
            `/workspaces/course_author/${project}/curriculum/${result.revision_slug}/edit`,
          );
        }
        return result;
      }
      return result;
    });
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
  editorsRef: React.RefObject<HTMLDivElement> = React.createRef();

  constructor(props: PageEditorProps) {
    super(props);

    const { title, objectives, allObjectives, content, allTags, defaultEditor } = props;

    setDefaultEditor(defaultEditor);

    const activityContexts = Immutable.OrderedMap<string, ActivityEditContext>(
      this.props.activityContexts.map((c) => {
        return [c.activitySlug, c];
      }),
    );

    const appsignal = initAppSignal(props.appsignalKey, 'Core Authoring Editor', {
      projectSlug: props.projectSlug,
      resourceSlug: props.resourceSlug,
      resourceId: String(props.resourceId),
    });

    this.state = {
      activityContexts,
      messages: [],
      editMode: false,
      title,
      allTags: Immutable.List<Tag>(allTags),
      objectives: Immutable.List<ResourceId>(objectives.attached),
      content: PageEditorContent.fromPersistence(content),
      persistence: 'idle',
      allObjectives: arrangeObjectives(allObjectives),
      childrenObjectives: mapChildrenObjectives(allObjectives),
      undoables: empty(),
      appsignal,
    };

    this.persistence = new DeferredPersistenceStrategy();

    this.update = this.update.bind(this);
    this.onEditActivity = this.onEditActivity.bind(this);
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

  onEditActivity(id: string, update: ActivityEditorUpdate): void {
    // only update if editMode is active
    if (!this.state.editMode) return;

    const constrainedContent = this.adjustActivityForConstraints(
      this.state.activityContexts.get(id)?.typeSlug,
      update.content,
    );
    const withModel = {
      model: update.content,
      title: update.title,
      objectives: update.objectives,
      tags: update.tags,
    };
    // apply the edit
    const merged = Object.assign({}, this.state.activityContexts.get(id), withModel);
    const activityContexts = this.state.activityContexts.set(id, merged);

    this.setState({ activityContexts }, () => {
      const saveFn = (releaseLock: boolean) =>
        ActivityPersistence.edit(
          this.props.projectSlug,
          this.props.resourceId,
          merged.activityId,
          { ...update, content: constrainedContent },
          releaseLock,
        );

      this.activityPersistence[id].save(saveFn);
    });
  }

  onRemove(key: string) {
    // only update if editMode is active
    if (!this.state.editMode) return;

    const item = this.state.content.find(key);
    const index = this.state.content.findIndex((c) => c.id === key);

    if (item !== undefined) {
      const undoable: PageUndoable = {
        type: 'PageUndoable',
        description: 'Removed ' + getResourceContentName(item),
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
        if (this.state.content.find(item.contentKey)) {
          // undoable content item exists, replace it with the undoable state
          this.update({
            content: this.state.content.replaceAt(item.undoable.index, item.undoable.item),
          });
        } else {
          // undoable content item does not exist, so insert it
          this.update({
            content: this.state.content.insertAt(item.undoable.index, item.undoable.item),
          });
        }
      } else {
        const context = this.state.activityContexts.get(item.contentKey);
        if (context !== undefined) {
          // Perform a deep copy
          const model = JSON.parse(JSON.stringify(context.model));

          // Apply the undo operations to the model
          Operations.applyAll(model as any, item.undoable.operations);

          // Now save the change and push it down to the activity editor
          this.onEditActivity(item.contentKey, {
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
    // only update if editMode is active
    if (!this.state.editMode) return;

    const mergedState = Object.assign({}, this.state, update);
    this.setState(mergedState, () => this.save());
  }

  updateImmediate(update: Partial<EditorUpdate>) {
    // only update if editMode is active
    if (!this.state.editMode) return;

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
  static adjustContentForConstraints(content: PageEditorContent): PageEditorContent {
    return content.updateAll((c: ResourceContent) => {
      if (c.type === 'selection') {
        return Object.assign({}, c, { logic: guaranteeValididty(c.logic) });
      }
      return c;
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

    const adjusted = PageEditor.adjustContentForConstraints(this.state.content);

    const toSave: Persistence.ResourceUpdate = {
      objectives: { attached: this.state.objectives.toArray() },
      title: this.state.title,
      content: adjusted.toPersistence(),
      releaseLock: false,
    };

    this.persistence.save(prepareSaveFn(projectSlug, resourceSlug, toSave));
  }

  saveImmediate() {
    const { projectSlug, resourceSlug } = this.props;

    const toSave: Persistence.ResourceUpdate = {
      objectives: { attached: this.state.objectives.toArray() },
      title: this.state.title,
      content: this.state.content.toPersistence(),
      releaseLock: false,
    };

    this.persistence.saveImmediate(prepareSaveFn(projectSlug, resourceSlug, toSave));
  }

  render() {
    const props = this.props;
    const state = this.state;

    const { projectSlug, resourceSlug } = this.props;

    const onEdit = (content: PageEditorContent) => this.update({ content });

    const onTitleEdit = (title: string) => {
      this.updateImmediate({ title });
    };

    const onAddItem = (
      c: StructuredContent | ActivityReference,
      index: number[],
      a?: ActivityEditContext,
    ) => {
      this.update({
        content: this.state.content.insertAt(index, c),
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
      <button
        className={`btn btn-sm btn-outline-primary ml-3 ${isSaving ? 'disabled' : ''}`}
        disabled={isSaving}
        onClick={() =>
          window.open(
            `/authoring/project/${projectSlug}/preview/${resourceSlug}`,
            `preview-${projectSlug}`,
          )
        }
      >
        <i className="fa-regular fa-file-lines mr-1"></i> Preview
      </button>
    );

    const dismissMessage = (msg: any) =>
      this.setState({
        messages: this.state.messages.filter((m) => msg.guid !== m.guid),
      });
    const executeAction = (message: any, action: any) => action.execute(message);

    return (
      <React.StrictMode>
        <AppsignalContext.Provider value={this.state.appsignal}>
          <ErrorBoundary>
            <div className="resource-editor row">
              <div className="col-span-12">
                <UndoToasts undoables={this.state.undoables} onInvokeUndo={this.onInvokeUndo} />

                <Banner
                  dismissMessage={dismissMessage}
                  executeAction={executeAction}
                  messages={this.state.messages}
                />
                <TitleBar
                  title={state.title}
                  onTitleEdit={onTitleEdit}
                  editMode={this.state.editMode}
                  dismissMessage={dismissMessage}
                  executeAction={executeAction}
                  messages={this.state.messages}
                >
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

                <div className="d-flex flex-row">
                  <AlternativesContextProvider projectSlug={projectSlug}>
                    <ContentOutline
                      editMode={this.state.editMode}
                      content={this.state.content}
                      activityContexts={this.state.activityContexts}
                      editorMap={props.editorMap}
                      projectSlug={projectSlug}
                      resourceSlug={resourceSlug}
                      onEditContent={onEdit}
                    />
                    <Editors
                      {...props}
                      editorsRef={this.editorsRef}
                      editMode={this.state.editMode}
                      objectives={this.state.allObjectives}
                      allTags={this.state.allTags}
                      childrenObjectives={this.state.childrenObjectives}
                      onRegisterNewObjective={onRegisterNewObjective}
                      onRegisterNewTag={onRegisterNewTag}
                      activityContexts={this.state.activityContexts}
                      onRemove={(key: string) => this.onRemove(key)}
                      onEdit={onEdit}
                      onEditActivity={this.onEditActivity}
                      onPostUndoable={this.onPostUndoable}
                      content={this.state.content}
                      onAddItem={onAddItem}
                      resourceContext={props}
                    />
                  </AlternativesContextProvider>
                </div>
              </div>
            </div>
          </ErrorBoundary>
        </AppsignalContext.Provider>
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
