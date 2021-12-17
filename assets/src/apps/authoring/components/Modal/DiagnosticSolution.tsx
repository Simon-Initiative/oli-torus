import React, { Fragment } from 'React';
import { clone } from 'utils/common';
import guid from 'utils/guid';
import { findReferencedActivitiesInConditions } from 'adaptivity/rules-engine';
import { DiagnosticTypes } from './DiagnosticTypes';
import { updatePart } from 'apps/authoring/store/parts/actions/updatePart';
import { saveActivity } from '../../../authoring/store/activities/actions/saveActivity';
import { findInSequence } from '../../../delivery/store/features/groups/actions/sequence';
import ScreenDropdownTemplate from '../PropertyEditor/custom/ScreenDropdownTemplate';

export interface SolutionProps {
  problem?: any;
  suggestion: string;
  onClick: (val: string) => void;
}

export const FixIdButton: React.FC<SolutionProps> = ({ suggestion, onClick }: SolutionProps) => {
  const txtRef = React.useRef<HTMLInputElement>(null);

  const handleClick = () => {
    if (txtRef.current && onClick) {
      const newVal = txtRef.current.value;
      onClick(newVal);
    }
  };

  return (
    <>
      <input ref={txtRef} type="text" defaultValue={suggestion} />
      <button className="btn btn-sm btn-primary" onClick={handleClick}>
        Apply
      </button>
    </>
  );
};

export const FixBrokenPathButton: React.FC<SolutionProps> = ({ onClick }: SolutionProps) => {
  const txtRef = React.createRef<HTMLInputElement>();

  // const [target, setTarget] = React.useState('invalid');

  const target = 'invalid';

  const uuid = guid();

  const handleClick = () => {
    if (txtRef.current && onClick) {
      const newVal = txtRef.current.value;
      onClick(newVal);
    }
  };

  const onChangeHandler = (sequenceId: string) => {
    console.log('onChange picker', sequenceId);
    onClick(sequenceId);
    // setTarget(sequenceId || 'invalid');
  };

  return (
    <div className="aa-action d-flex mb-2 form-inline align-items-center flex-nowrap">
      <label className="sr-only" htmlFor={`action-navigation-${uuid}`}>
        SequenceId
      </label>
      <div className="input-group input-group-sm flex-grow-1">
        <div className="input-group-prepend">
          <div className="input-group-text">
            <i className="fa fa-compass mr-1" />
            Navigate To
          </div>
        </div>
        <ScreenDropdownTemplate
          id={`action-navigation-${uuid}`}
          label=""
          value={target}
          onChange={onChangeHandler}
          dropDownCSSClass="adaptivityDropdown form-control"
          buttonCSSClass="form-control-sm"
        />
      </div>
      <button className="btn btn-sm btn-primary ml-2" onClick={handleClick}>
        Apply
      </button>
    </div>
  );
};

export const DiagnosticSolution: React.FC<SolutionProps> = (props: SolutionProps) => {
  const { problem } = props;
  const { type = DiagnosticTypes.DEFAULT } = problem;
  let action;
  switch (type) {
    case DiagnosticTypes.DUPLICATE:
      action = <FixIdButton {...props} />;
      break;
    case DiagnosticTypes.PATTERN:
      action = <FixIdButton {...props} />;
      break;
    case DiagnosticTypes.BROKEN:
      action = <FixBrokenPathButton {...props} />;
      break;
    default:
      action = <Fragment />;
      break;
  }
  return <Fragment>{action}</Fragment>;
};

export const updateId = (problem: any, fixed: string) => {
  const activityId = problem.owner.resourceId;
  const partId = problem.item.id;
  const changes = { id: fixed };
  return updatePart({ activityId, partId, changes });
};

const handleRuleChange = (rule: any, activity: any, sequence: any) => {
  const existing = activity?.authoring.rules.find((r: any) => r.id === rule.id);
  const diff = JSON.stringify(rule) !== JSON.stringify(existing);
  console.log('RULE CHANGE: ', {
    rule,
    existing,
    diff,
  });
  if (!existing) {
    console.warn("rule not found, shouldn't happen!!!");
    return;
  }
  if (diff) {
    const activityClone = clone(activity);
    const rulesClone = [...activity?.authoring.rules];
    rulesClone[activity?.authoring.rules.indexOf(existing)] = rule;
    activityClone.authoring.rules = rulesClone;
    // due to the way this works technically if we are *deleting" a condition with an external reference
    // then it will *not* be removed here, but it will be removed the next time the lesson is opened in the editor
    const conditionRefs = findReferencedActivitiesInConditions(
      rule.conditions.any || rule.conditions.all,
    );
    if (conditionRefs.length > 0) {
      if (!activityClone.authoring.activitiesRequiredForEvaluation) {
        activityClone.authoring.activitiesRequiredForEvaluation = [];
      }
      // need to find the resourceId based on the sequenceId that is referenced
      const resourceIds = conditionRefs
        .map((conditionRef: any) => {
          const sequenceItem = findInSequence(sequence, conditionRef);
          if (sequenceItem) {
            return sequenceItem.resourceId;
          } else {
            console.warn(
              `[handleRuleChange] could not find referenced activity ${conditionRef} in sequence`,
              sequence,
            );
          }
        })
        .filter((id) => id) as number[];
      const current = activityClone.authoring.activitiesRequiredForEvaluation;
      activityClone.authoring.activitiesRequiredForEvaluation = Array.from(
        new Set([...current, ...resourceIds]),
      );
      /* console.log('[handleRuleChange] adding activities to required for evaluation', {
        activityClone,
        rule,
      }); */
    }
    return saveActivity({ activity: activityClone });
  }
};

const updaters = {
  [DiagnosticTypes.DUPLICATE]: updateId,
  [DiagnosticTypes.PATTERN]: updateId,
  [DiagnosticTypes.BROKEN]: handleRuleChange,
  [DiagnosticTypes.DEFAULT]: () => {},
};

export const createUpdater = (type: DiagnosticTypes): any => updaters[type];
