import React, { Fragment } from 'React';
import { clone } from 'utils/common';
import { findReferencedActivitiesInConditions } from 'adaptivity/rules-engine';
import { DiagnosticTypes } from './DiagnosticTypes';
import { updatePart } from 'apps/authoring/store/parts/actions/updatePart';
import { saveActivity } from '../../../authoring/store/activities/actions/saveActivity';
import { findInSequence } from '../../../delivery/store/features/groups/actions/sequence';

export interface Solution {
  problem: any;
  suggestion: string;
  onClick: (val: string) => void;
}

export const FixIdButton: React.FC<Solution> = ({ suggestion, onClick }) => {
  const txtRef = React.createRef<HTMLInputElement>();

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

export const FixBrokenPathButton: React.FC<Solution> = ({ suggestion, onClick }) => {
  const txtRef = React.createRef<HTMLInputElement>();

  const handleClick = () => {
    if (txtRef.current && onClick) {
      const newVal = txtRef.current.value;
      onClick(newVal);
    }
  };

  return (
    <>
      Fix Broken Path
      <input ref={txtRef} type="text" defaultValue={suggestion} />
      <button className="btn btn-sm btn-primary" onClick={handleClick}>
        Apply
      </button>
    </>
  );
};

export const Solutions: { [type: string]: React.FC<Solution> } = {
  [DiagnosticTypes.PATTERN]: FixIdButton,
  [DiagnosticTypes.DUPLICATE]: FixIdButton,
  [DiagnosticTypes.BROKEN]: FixBrokenPathButton,
};

export const DiagnosticSolution: React.FC<Solution> = (props) => {
  const Solution = Solutions[props.problem.type] || Fragment;

  return <Solution {...props} />;
};

export const updateId = (problem: any, fixed: string) => {
  const activityId = problem.owner.resourceId;
  const partId = problem.item.id;
  const changes = { id: fixed };
  return updatePart({ activityId, partId, changes });
};

export const updateTarget = (problem: any, fix: string) => {
  // console.log('updateTarget', problem, fix);
  return handleRuleChange({}, problem.item, problem.sequence);
};

const handleRuleChange = (rule: any, activity: any, sequence: any) => {
  const existing = activity?.authoring.rules.find((r: any) => r.id === rule.id);
  const diff = JSON.stringify(rule) !== JSON.stringify(existing);
  /* console.log('RULE CHANGE: ', {
    rule,
    existing,
    diff,
  }); */
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
