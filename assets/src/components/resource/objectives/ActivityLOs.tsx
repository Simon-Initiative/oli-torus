import React from 'react';
import { Objective } from 'data/content/objective';
import { ObjectivesSelection } from 'components/resource/objectives/ObjectivesSelection';
import { ObjectiveMap } from 'data/content/activity';
import { Objectives } from 'components/resource/objectives/Objectives';
import { classNames } from 'utils/classNames';

type Props = {
  partIds: string[];
  objectives: ObjectiveMap;
  allObjectives: Objective[];
  editMode: boolean;
  projectSlug: string;
  onEdit: (objectives: ObjectiveMap) => void;
  onRegisterNewObjective: (objective: Objective) => void;
};

// Allows attaching and removal of objectives to activity parts
export const ActivityLOs = (props: Props) => {
  if (props.partIds.length === 0) return null;
  const singlePartActivity = props.partIds.length === 1;

  return (
    <Objectives>
      {!singlePartActivity && <MultiPartSelections {...props} />}
      {singlePartActivity && <SinglePartSelection {...props} />}
    </Objectives>
  );
};

const MultiPartSelection = (props: Props & { id: string; index: number }) => {
  const isLast = props.index === props.partIds.length - 1;
  const style = { flexBasis: props.partIds.length >= 10 ? '60px' : '50px' };

  const PartLabel = () => (
    <div className="mr-2" style={style}>
      Part {props.index + 1}
    </div>
  );

  return (
    <div className={classNames('d-flex', 'flex-row', 'align-items-baseline', isLast && 'mb-1')}>
      <PartLabel />
      <ObjectivesSelection
        {...props}
        selected={props.objectives[props.id] || []}
        objectives={props.allObjectives}
        onEdit={(objectives) =>
          props.onEdit({ ...props.objectives, ...{ [props.id]: objectives } })
        }
      />
    </div>
  );
};
const MultiPartSelections = (props: Props) => (
  <>
    {props.partIds.map((id, index) => (
      <MultiPartSelection {...props} id={id} index={index} key={id} />
    ))}
  </>
);

const SinglePartSelection = (props: Props) => {
  const partId = props.partIds[0];
  return (
    <ObjectivesSelection
      {...props}
      selected={props.objectives[partId]}
      objectives={props.allObjectives}
      onEdit={(objectives) => props.onEdit({ ...props.objectives, ...{ [partId]: objectives } })}
    />
  );
};
