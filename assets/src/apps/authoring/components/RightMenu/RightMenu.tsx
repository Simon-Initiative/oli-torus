/* eslint-disable @typescript-eslint/ban-types */
import React, { useCallback, useMemo } from 'react';
import { Tab, Tabs } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { UiSchema } from '@rjsf/core';
import { JSONSchema7 } from 'json-schema';
import { clone } from 'utils/common';
import {
  selectAppMode,
  selectRightPanelActiveTab,
  setRightPanelActiveTab,
} from '../../../authoring/store/app/slice';
import { IPartLayout } from '../../../delivery/store/features/activities/slice';
import {
  SequenceBank,
  SequenceEntry,
  findInSequence,
} from '../../../delivery/store/features/groups/actions/sequence';
import {
  selectCurrentActivityTree,
  selectCurrentSequenceId,
  selectSequence,
} from '../../../delivery/store/features/groups/selectors/deck';
import { selectCurrentGroup } from '../../../delivery/store/features/groups/slice';
import { saveActivity } from '../../store/activities/actions/saveActivity';
import { updateSequenceItem } from '../../store/groups/layouts/deck/actions/updateSequenceItemFromActivity';
import { savePage } from '../../store/page/actions/savePage';
import { selectState as selectPageState } from '../../store/page/slice';
import { selectCurrentSelection, setCurrentPartPropertyFocus } from '../../store/parts/slice';
import PropertyEditor from '../PropertyEditor/PropertyEditor';
import bankSchema, {
  bankUiSchema,
  transformBankModeltoSchema,
  transformBankSchematoModel,
} from '../PropertyEditor/schemas/bank';
import bankPropsSchema, {
  BankPropsUiSchema,
  transformBankPropsModeltoSchema,
  transformBankPropsSchematoModel,
} from '../PropertyEditor/schemas/bankScreen';
import lessonSchema, {
  lessonUiSchema,
  simpleLessonSchema,
  simpleLessonUiSchema,
  transformModelToSchema as transformLessonModel,
  transformSchemaToModel as transformLessonSchema,
} from '../PropertyEditor/schemas/lesson';
import screenSchema, {
  screenUiSchema,
  simpleScreenSchema,
  simpleScreenUiSchema,
  transformScreenModeltoSchema,
  transformScreenSchematoModel,
} from '../PropertyEditor/schemas/screen';
import { PartPropertyEditor } from './PartPropertyEditor';

export enum RightPanelTabs {
  LESSON = 'lesson',
  SCREEN = 'screen',
  COMPONENT = 'component',
}

const RightMenu: React.FC<any> = () => {
  const dispatch = useDispatch();
  const selectedTab = useSelector(selectRightPanelActiveTab);
  const currentActivityTree = useSelector(selectCurrentActivityTree);
  const currentLesson = useSelector(selectPageState);
  const currentGroup = useSelector(selectCurrentGroup);
  const currentPartSelection = useSelector(selectCurrentSelection);
  const appMode = useSelector(selectAppMode);
  const flowchartMode = appMode === 'flowchart';

  // TODO: dynamically load schema from Part Component configuration
  const currentSequenceId = useSelector(selectCurrentSequenceId);
  const sequence = useSelector(selectSequence);
  const currentSequence = findInSequence(sequence, currentSequenceId || '');

  const [currentActivity] = (currentActivityTree || []).slice(-1);

  const scrUiSchema = useMemo(
    () =>
      currentSequence?.custom.isBank
        ? BankPropsUiSchema
        : flowchartMode
        ? simpleScreenUiSchema
        : screenUiSchema,
    [currentSequence?.custom.isBank, flowchartMode],
  );

  const scrSchema = useMemo(
    () =>
      currentSequence?.custom.isBank
        ? bankPropsSchema
        : flowchartMode
        ? simpleScreenSchema
        : screenSchema,
    [currentSequence?.custom.isBank, flowchartMode],
  );

  const questionBankData = useMemo(
    () => transformBankModeltoSchema(currentSequence as SequenceEntry<SequenceBank>),
    [currentSequence],
  );

  const scrData = useMemo(
    () =>
      !currentActivity
        ? null
        : currentSequence?.custom.isBank
        ? transformBankPropsModeltoSchema(currentActivity)
        : transformScreenModeltoSchema(currentActivity),
    [currentActivity, currentSequence],
  );

  const existingIds = useMemo(
    () =>
      currentActivityTree?.reduce((acc, activity) => {
        const ids: string[] = (activity.content?.partsLayout || []).map(
          (p: IPartLayout): string => p.id,
        );
        return acc.concat(ids);
      }, [] as string[]) || [],
    [currentActivityTree],
  );

  // should probably wrap this in state too, but it doesn't change really
  const lessonData = transformLessonModel(currentLesson);

  const handleSelectTab = (key: RightPanelTabs) => {
    // TODO: any other saving or whatever
    dispatch(setRightPanelActiveTab({ rightPanelActiveTab: key }));
  };

  const bankPropertyChangeHandler = useCallback(
    (properties: object) => {
      if (currentSequence) {
        const modelChanges = transformBankSchematoModel(properties);
        /* console.log('Bank Property Change...', { properties, modelChanges }); */
        const { bankShowCount, bankEndTarget } = modelChanges;
        if (currentSequence) {
          const cloneSequence = clone(currentSequence);
          cloneSequence.custom.bankShowCount = bankShowCount;
          cloneSequence.custom.bankEndTarget = bankEndTarget;
          dispatch(updateSequenceItem({ sequence: cloneSequence, group: currentGroup }));
          dispatch(savePage({ undoable: true }));
        }
      }
    },
    [currentGroup, currentSequence, dispatch],
  );

  const screenPropertyChangeHandler = useCallback(
    (properties: object) => {
      if (currentActivity) {
        const modelChanges = currentSequence?.custom.isBank
          ? transformBankPropsSchematoModel(properties)
          : transformScreenSchematoModel(properties);
        /* console.log('Screen Property Change...', { properties, modelChanges }); */
        const { title, ...screenModelChanges } = modelChanges;
        const objectives = modelChanges.objectives || [];

        const screenChanges = {
          ...currentActivity?.content?.custom,
          ...screenModelChanges,
        };
        const cloneActivity = clone(currentActivity);
        cloneActivity.content.custom = screenChanges;

        if (objectives.length === 0) {
          // Potentially removing all objectives, clear them out
          cloneActivity.objectives = {};
        } else if (currentActivity.authoring?.parts && currentActivity.authoring.parts.length > 0) {
          // Adding objectives, and we have an existing part to attach them to.
          cloneActivity.objectives = {
            [currentActivity.authoring.parts[0].id]: objectives,
          };
        } else {
          // Adding objectives, but there are no parts to attach them to, saveActivity.ts will create a __default part for us
          cloneActivity.objectives = {
            __default: objectives,
          };
        }

        if (title) {
          cloneActivity.title = title;
        }
        if (JSON.stringify(cloneActivity) !== JSON.stringify(currentActivity)) {
          dispatch(saveActivity({ activity: cloneActivity, undoable: true }));
        }
      }
    },
    [currentActivity],
  );

  const lessonPropertyChangeHandler = useCallback(
    (properties: object) => {
      const modelChanges = transformLessonSchema(properties);

      // special consideration for legacy stylesheets
      if (modelChanges.additionalStylesheets[0] === null) {
        modelChanges.additionalStylesheets[0] = (currentLesson.additionalStylesheets || [])[0];
      }

      const lessonChanges = {
        ...currentLesson,
        ...modelChanges,
        custom: { ...currentLesson.custom, ...modelChanges.custom },
      };

      //need to remove the allowNavigation property
      //making sure the enableHistory is present before removing that.
      if (
        lessonChanges.custom.enableHistory !== undefined &&
        lessonChanges.custom.allowNavigation !== undefined
      ) {
        delete lessonChanges.custom.allowNavigation;
      }
      // console.log('LESSON PROP CHANGED', {
      //   modelChanges,
      //   lessonChanges,
      //   properties,
      //   currentLesson,
      // });

      // need to put a healthy debounce in here, this fires every keystroke
      // save the page
      if (JSON.stringify(lessonChanges) !== JSON.stringify(currentLesson)) {
        dispatch(savePage({ ...lessonChanges, undoable: true }));
      }
    },
    [currentLesson, dispatch],
  );

  const onfocusHandler = useCallback(
    (partPropertyElementFocus: any) => {
      dispatch(setCurrentPartPropertyFocus({ focus: partPropertyElementFocus }));
    },
    [currentActivity, dispatch],
  );

  return (
    <Tabs
      className="aa-panel-section-title-bar aa-panel-tabs"
      activeKey={selectedTab}
      onSelect={handleSelectTab}
    >
      <Tab eventKey={RightPanelTabs.LESSON} title="Lesson">
        <div className="lesson-tab overflow-hidden">
          <PropertyEditor
            schema={flowchartMode ? simpleLessonSchema : lessonSchema}
            uiSchema={flowchartMode ? simpleLessonUiSchema : lessonUiSchema}
            value={lessonData}
            triggerOnChange={['CustomLogic']}
            onChangeHandler={lessonPropertyChangeHandler}
            onfocusHandler={onfocusHandler}
          />
        </div>
      </Tab>
      <Tab eventKey={RightPanelTabs.SCREEN} title="Screen">
        {currentActivity && currentSequence && currentSequence?.custom.isBank ? (
          <div className="bank-tab p-3">
            <PropertyEditor
              key={currentActivity.id}
              schema={bankSchema}
              uiSchema={bankUiSchema}
              value={questionBankData}
              onChangeHandler={bankPropertyChangeHandler}
              triggerOnChange={true}
              onfocusHandler={onfocusHandler}
            />
          </div>
        ) : null}
        <div className="screen-tab p-3 overflow-hidden">
          {currentActivity && scrData ? (
            <PropertyEditor
              key={currentActivity.id}
              schema={scrSchema as JSONSchema7}
              uiSchema={scrUiSchema as UiSchema}
              value={scrData}
              onChangeHandler={screenPropertyChangeHandler}
              onfocusHandler={onfocusHandler}
            />
          ) : null}
        </div>
      </Tab>
      <Tab eventKey={RightPanelTabs.COMPONENT} title="Component" disabled={!currentPartSelection}>
        {currentPartSelection && currentActivityTree && (
          <PartPropertyEditor
            currentActivityTree={currentActivityTree}
            currentActivity={currentActivity}
            currentPartSelection={currentPartSelection}
            existingIds={existingIds}
          />
        )}
      </Tab>
    </Tabs>
  );
};

export default RightMenu;
