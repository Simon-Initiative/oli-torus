import * as Immutable from 'immutable';
import React, { useState } from 'react';
import isHotkey from 'is-hotkey';
import {
  ResourceContent, Activity, ResourceType, ActivityPurposes, ContentPurposes,
  ActivityReference, StructuredContent, ResourceContext,
} from 'data/content/resource';
import { ActivityEditorMap, EditorDesc } from 'data/content/editors';
import { UnsupportedActivity } from './UnsupportedActivity';
import { getToolbarForResourceType } from './toolbar';
import { StructuredContentEditor } from 'components/content/StructuredContentEditor';
import { ProjectSlug, ResourceSlug } from 'data/types';
import { AbbreviatedActivity } from './AbbreviatedActivity';
import { Purpose } from '../content/Purpose';
import { DeleteButton } from '../misc/DeleteButton';
import * as Persistence from 'data/persistence/activity';
import { EditLink } from '../misc/EditLink';
import { Objective, ObjectiveSlug } from 'data/content/objective';
import { getContentDescription } from 'data/content/utils';
import { toSimpleText } from 'data/content/text';
import { DragHandle } from './DragHandle';
import { classNames } from 'utils/classNames';
import { AddResourceContent } from '../content/AddResourceContent';

export type EditorsProps = {
  editMode: boolean,              // Whether or not we can edit
  content: Immutable.List<ResourceContent>,     // Content of the resource
  onEdit: (content: ResourceContent, index: number) => void,
  onEditContentList: (content: Immutable.List<ResourceContent>) => void,
  onRemove: (index: number) => void,
  onAddItem: (c : ResourceContent, index: number, a? : Activity) => void,
  editorMap: ActivityEditorMap,   // Map of activity types to activity elements
  graded: boolean,
  activities: Immutable.Map<string, Activity>,
  projectSlug: ProjectSlug,
  resourceSlug: ResourceSlug,
  resourceContext: ResourceContext,
  objectives: Immutable.List<Objective>,
  childrenObjectives: Immutable.Map<ObjectiveSlug, Immutable.List<Objective>>,
  onRegisterNewObjective: (text: string) => Promise<Objective>,
};

interface ActivityPayload {
  type: 'ActivityPayload';
  id: string;
  activity: Activity;
  reference: ActivityReference;
  project: ProjectSlug;
}

interface UnknownPayload {
  type: 'UnknownPayload';
  id: string;
  data: any;
}

type DragPayload = StructuredContent | ActivityPayload | UnknownPayload;

// @ts-ignore
const DropTarget = ({ id, index, isLast, onDrop }) => {
  const [hovered, setHovered] = useState(false);

  const handleDragEnter = (e: React.DragEvent<HTMLDivElement>) => setHovered(true);
  const handleDragLeave = (e: React.DragEvent<HTMLDivElement>) => setHovered(false);
  const handleDrop = (e: React.DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    setHovered(false);
    onDrop(e, index);
  };
  const handleOver = (e: React.DragEvent<HTMLDivElement>) => {
    e.stopPropagation();
    e.preventDefault();
  };

  return (
    <div key={id + '-drop'}
      className={classNames(['drop-target ', hovered ? 'hovered' : '', isLast ? 'is-last' : ''])}
      onDragEnter={handleDragEnter}
      onDragLeave={handleDragLeave}
      onDrop={handleDrop}
      onDragOver={handleOver}>
    </div>
  );
};

type AddResourceOrDropTargetProps = {
  isReorderMode: boolean,
  id: string,
  index: number,
  editMode: boolean,
  editorMap: ActivityEditorMap,
  resourceContext: ResourceContext,
  onDrop: (e: React.DragEvent<HTMLDivElement>, index: number) => void,
  onAddItem: (c : ResourceContent, index: number, a? : Activity) => void,
  objectives: Immutable.List<Objective>,
  childrenObjectives: Immutable.Map<ObjectiveSlug, Immutable.List<Objective>>,
  onRegisterNewObjective: (text: string) => Promise<Objective>,
};

const AddResourceOrDropTarget = ({
  isReorderMode,
  id,
  index,
  editMode,
  editorMap,
  resourceContext,
  onDrop,
  onAddItem,
  objectives,
  childrenObjectives,
  onRegisterNewObjective,
}: AddResourceOrDropTargetProps) => isReorderMode
  ? (
    <DropTarget id={id} index={index} isLast={id === 'last'} onDrop={onDrop}/>
  )
  : (
    <AddResourceContent
      objectives={objectives}
      childrenObjectives={childrenObjectives}
      onRegisterNewObjective={onRegisterNewObjective}
      editMode={editMode}
      isLast={id === 'last'}
      index={index}
      onAddItem={onAddItem}
      editorMap={editorMap}
      resourceContext={resourceContext} />
  );

const getFriendlyName = (item: ActivityReference, editorMap: ActivityEditorMap,
  activities: Immutable.Map<string, Activity>) => {

  const activity = activities.get(item.activitySlug);
  return editorMap[(activity as any).typeSlug].friendlyName;
};

const getDescription = (item: ResourceContent) => {

  const summary = item.type === 'content'
      ? getContentDescription(item)
      : '';

  return summary;
};

// The list of editors
export const Editors = (props: EditorsProps) => {

  const objectivesMap =  props.resourceContext.allObjectives.reduce(
    (m: any, o) => {
      m[o.slug] = o.title;
      return m;
    },
    {},
  );

  const {
    editorMap, editMode, graded, content, activities, projectSlug,
    resourceSlug, onEditContentList, onAddItem,
  } = props;

  // Factory for creating top level editors, for things like structured
  // content or referenced activities
  const createEditor = (
    content: ResourceContent,
    onEdit: (content: ResourceContent) => void,
    ) : [JSX.Element, string] => {

    if (content.type === 'content') {
      return [
        <StructuredContentEditor
          key={content.id}
          editMode={editMode}
          content={content}
          onEdit={onEdit}
          projectSlug={projectSlug}
          toolbarItems={getToolbarForResourceType(
            graded ? ResourceType.assessment : ResourceType.page)}
          toolbarPosition={{ top: 8, left: 20 }}/>,
        'Content',
      ];
    }


    const unsupported : EditorDesc = {
      deliveryElement: UnsupportedActivity,
      authoringElement: UnsupportedActivity,
      icon: '',
      description: 'Not supported',
      friendlyName: 'Not supported',
      slug: 'unknown',
    };

    const activity = activities.get(content.activitySlug);

    let friendlyName = 'Unknown';
    let previewText = '';
    let objectives = [];

    if (activity !== undefined) {

      const editor = editorMap[activity.typeSlug]
        ? editorMap[activity.typeSlug] : unsupported;
      friendlyName = editor.friendlyName;

      if (activity.model.authoring !== undefined) {
        if (activity.model.authoring.previewText !== undefined) {
          previewText = activity.model.authoring.previewText;
        }

        const slugsAsKeys = Object.keys(activity.objectives)
          .reduce((map: any, key) => {
            (activity.objectives as any)[key as any].forEach((slug: string) => {
              map[slug] = true;
            });
            return map;
          },
          {});

        objectives = Object.keys(slugsAsKeys)
          .map(slug => objectivesMap[slug]);
      }

    }

    const abbreviatedActivity = (
      <AbbreviatedActivity
        previewText={previewText}
        objectives={objectives}/>
    );

    return [abbreviatedActivity, friendlyName];

  };

  const [assisstive, setAssisstive] = useState('');

  const onFocus = (index: number) => {
    const item = content.get(index) as ResourceContent;
    const desc = item.type === 'content'
      ? getContentDescription(item)
      : getFriendlyName(item, editorMap, activities);

    setAssisstive(
      `Listbox. ${index + 1} of ${content.size}. ${desc}.`);
  };

  const onMove = (index: number, up: boolean) => {

    if (index === 0 && up) return;

    const item = content.get(index) as ResourceContent;
    const inserted = content
      .remove(index)
      .insert(index + (up ? -1 : 1), item as any);

    onEditContentList(inserted);

    const newIndex = inserted.findIndex(c => c.id === item.id);
    const desc = item.type === 'content'
      ? 'Content' : getFriendlyName(item, editorMap, activities);

    setAssisstive(
      `Listbox. ${newIndex + 1} of ${content.size}. ${desc}.`);
  };

  const [activeDragId, setActiveDragId] = useState<string | null>(null);
  const isReorderMode = activeDragId !== null;

  const handleDragEnd = () => {
    setActiveDragId(null);
  };

  const scrollToResourceEditor = (contentId: string) => {
    setTimeout(() => {
      document.querySelector(`#re${contentId}`)?.scrollIntoView({ behavior: 'smooth' });
    });
  };

  const onDrop = (e: React.DragEvent<HTMLDivElement>, index: number) => {
    handleDragEnd();

    if (editMode) {
      const data = e.dataTransfer.getData('application/x-oli-resource-content');

      if (data) {
        const droppedContent = JSON.parse(data) as DragPayload;

        const sourceIndex = content.findIndex(c => c.id === droppedContent.id);

        if (sourceIndex === -1) {

          // This is a cross window drop, we insert it but have to have to
          // ensure that for activities that we create a new activity for
          // tied to this project
          if (droppedContent.type === 'ActivityPayload') {

            if (droppedContent.project !== projectSlug) {

              Persistence.create(
                droppedContent.project,
                droppedContent.activity.typeSlug,
                droppedContent.activity.model, [])
              .then((result: Persistence.Created) => {
                onEditContentList(content.insert(index, droppedContent.reference));
              });

            } else {
              onEditContentList(content.insert(index, droppedContent.reference));
            }


          } else if (droppedContent.type === 'content') {
            onEditContentList(content.insert(index, droppedContent));
          } else {
            onEditContentList(content.insert(index, droppedContent.data));
          }

          // scroll to inserted item
          scrollToResourceEditor(droppedContent.id);

          return;

        }
        if (sourceIndex > -1) {
          // Handle a same window drag and drop
          const adjusted = sourceIndex < index ? index - 1 : index;

          let toInsert;
          if (droppedContent.type === 'ActivityPayload') {
            toInsert = droppedContent.reference;
          } else if (droppedContent.type === 'content') {
            toInsert = droppedContent;
          } else {
            toInsert = droppedContent.data;
          }

          const reordered = content.remove(sourceIndex).insert(adjusted, toInsert);
          onEditContentList(reordered);

          // scroll to moved item
          scrollToResourceEditor(droppedContent.id);

          return;
        }
      }

      // Handle a drag and drop from VSCode
      const text = e.dataTransfer.getData('codeeditors');
      if (text) {
        try {
          const json = JSON.parse(text);
          const parsedContent = JSON.parse(json[0].content);

          // Remove it if we find the same identified content item
          const inserted = content
            .filter(c => parsedContent.id !== c.id)
            // Then insert it
            .insert(index, parsedContent);

          onEditContentList(inserted);

            // scroll to inserted item
          scrollToResourceEditor(parsedContent.id);
        } catch (err) {

        }
      }

    }
  };

  const editors = content.map((c, index) => {

    const onEdit = (u : ResourceContent) => props.onEdit(u, index);
    const onRemove = () => props.onRemove(index);
    const onEditPurpose = (purpose: string) => {
      const u = Object.assign(c, { purpose });
      props.onEdit(u, index);
    };

    const [editor, label] = createEditor(c, onEdit);

    const purposes = c.type === 'activity-reference'
      ? ActivityPurposes : ContentPurposes;

    let dragPayload : DragPayload;
    if (c.type === 'content') {
      dragPayload = c;
    } else if (activities.has(c.activitySlug)) {
      const activity = activities.get(c.activitySlug);
      dragPayload = {
        type: 'ActivityPayload',
        id: c.id,
        reference: c,
        activity: activity as Activity,
        project: projectSlug,
      } as ActivityPayload;
    } else {
      dragPayload = { type: 'UnknownPayload', data: c, id: c.id };
    }

    const handleDragStart = (e: React.DragEvent<HTMLDivElement>) => {
      const dt = e.dataTransfer;

      // Enables dragging of the underlying JSON of nodes into VSCode for
      // debugging / troubleshooting purposes
      const resource = JSON.stringify([{
        resource: '' + c.id,
        content: JSON.stringify(dragPayload, null, 2),
        viewState: null,
        encoding: 'UTF-8',
        mode: null,
        isExternal: false,
      }]);

      dt.setData('CodeEditors', resource);
      dt.setData('application/x-oli-resource-content', JSON.stringify(dragPayload));
      dt.setData('text/html', toSimpleText(c as any));
      dt.setData('text/plain', toSimpleText(c as any));
      dt.effectAllowed = 'move';

      // setting the reorder mode flag needs to happen at the end of the event loop to
      // ensure that all dom nodes that existed when the drag began still exist throughout
      // the entire event. This set timeout ensures this correct order of operations
      setTimeout(() => {
        setActiveDragId(c.id);
      });
    };

    // register keydown handlers
    const isShiftArrowDown = isHotkey('shift+down');
    const isShiftArrowUp = isHotkey('shift+up');

    const handleKeyDown = (e: React.KeyboardEvent) => {
      if (isShiftArrowDown(e.nativeEvent)) {
        onMove(index, false);
      } else if (isShiftArrowUp(e.nativeEvent)) {
        onMove(index, true);
      }
    };

    const resourceContentFrame = c.type === 'activity-reference'
    ? (
      <div className="resource-content-frame card">
        <div className="card-header pl-2"
          draggable={true}
          onDragStart={handleDragStart}
          onDragEnd={handleDragEnd}>
          <div className="d-flex flex-row align-items-baseline">

            <div className="flex-grow-1">
              <DragHandle style={{ height: 24, marginRight: 10 }} />
              <EditLink
                label={'Edit this ' + label + ' Activity'}
                href={`/project/${projectSlug}/resource/${resourceSlug}/activity/${c.activitySlug}`}
                />
            </div>
            <Purpose purpose={c.purpose} purposes={purposes}
              editMode={editMode} onEdit={(p: string) => onEditPurpose(p)}/>
            <DeleteButton editMode={content.size > 1} onClick={onRemove}/>
          </div>

          {editor}

        </div>



      </div>
    )
    : (
      <div className="resource-content-frame card">
        <div className="card-header pl-2"
          draggable={true}
          onDragStart={handleDragStart}
          onDragEnd={handleDragEnd}>
          <div className="d-flex flex-row align-items-baseline">
            <div className="flex-grow-1">
              <DragHandle style={{ height: 24, marginRight: 10 }} />
            </div>
            <Purpose purpose={c.purpose} purposes={purposes}
              editMode={editMode} onEdit={(p: string) => onEditPurpose(p)}/>
            <DeleteButton editMode={content.size > 1} onClick={onRemove}/>
          </div>
          <div className="description text-secondary ellipsize-overflow flex-1 mx-4 mt-2">
            {getDescription(c)}
          </div>
        </div>
        <div className="card-body">
          {editor}
        </div>
      </div>
    );

    return (
      <div key={c.id}
        id={`re${c.id}`}
        className={classNames([
          'resource-editor-and-controls',
          c.id, c.id === activeDragId ? 'is-dragging' : '',
        ])}>

        <AddResourceOrDropTarget
          id={c.id}
          objectives={props.objectives}
          childrenObjectives={props.childrenObjectives}
          onRegisterNewObjective={props.onRegisterNewObjective}
          index={index}
          editMode={editMode}
          isReorderMode={isReorderMode}
          editorMap={editorMap}
          resourceContext={props.resourceContext}
          onAddItem={onAddItem}
          onDrop={onDrop} />

        <div className={classNames(['resource-editor', isReorderMode ? 'reorder-mode' : ''])}
          onKeyDown={handleKeyDown}
          onFocus={e => onFocus(index)}
          role="option"
          aria-describedby="content-list-operation"
          tabIndex={index + 1}>

          {resourceContentFrame}

        </div>

      </div>
    );
  });

  return (
    <div className="editors d-flex flex-column flex-grow-1">
      {editors}

      <AddResourceOrDropTarget
        {...props}
        id="last"
        index={editors.size}
        editMode={editMode}
        isReorderMode={isReorderMode}
        editorMap={editorMap}
        resourceContext={props.resourceContext}
        onAddItem={onAddItem}
        onDrop={onDrop} />
    </div>
  );
};
