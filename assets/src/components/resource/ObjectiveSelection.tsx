import React, { useState } from 'react';
import * as Immutable from 'immutable';
import { Objective, ResourceId } from 'data/content/objective';

export type ObjectiveSelectionProps = {
  objectives: Immutable.List<Objective>;
  childrenObjectives: Immutable.Map<ResourceId, Immutable.List<Objective>>;
  onRegisterNewObjective: (title: string) => Promise<Objective>;
  onUseSelected: (objectives: Immutable.List<ResourceId>) => void;
};

type ObjectNodeProps = {
  objective: Objective,
  childrenObjectives: Immutable.Map<ResourceId, Immutable.List<Objective>>,
  level: number,
  selected: Object,
  toggleSelected: (id: ResourceId) => void,
};

const indentPerLevel = (level: number) => ({ marginLeft: (level * 15) + 'px' });

const ObjectiveNode = (props: ObjectNodeProps) => {

  const { objective, childrenObjectives, level } = props;

  const myChildren = childrenObjectives.get(objective.id);
  const renderedChildren = myChildren === undefined
    ? null
    : myChildren.toArray().map(o => <ObjectiveNode
       key={o.id}
       selected={props.selected}
       toggleSelected={props.toggleSelected}
       objective={o}
       childrenObjectives={childrenObjectives} level={level + 1}/>);

  return (
    <div key={objective.id}>
      <div
        key="title"
        onClick={() => props.toggleSelected(objective.id)}
        className={`title ${(props.selected as any)[objective.id] === true ? 'selected' : ''}`}
        style={indentPerLevel(level)}>
        {objective.title}
      </div>
      {renderedChildren}
    </div>
  );
};

const ObjectiveTree = (props: ObjectiveSelectionProps &
  { selected: Object, toggleSelected: (slug: ResourceId) => void}) => {
  return (
    <React.Fragment>
      {props.objectives.toArray()
        .filter(o => o.parentId === null)
        .map(o => <ObjectiveNode key={o.id} objective={o} selected={props.selected}
          toggleSelected={props.toggleSelected}
          childrenObjectives={props.childrenObjectives} level={1}/>)}
    </React.Fragment>
  );
};

export const ObjectiveSelection = (props: ObjectiveSelectionProps) => {

  const [selected, setSelected] = useState({});
  const [text, setText] = useState('');

  const toList = () =>
    props.objectives.filter(o => (selected as any)[o.id] === true).map(o => o.id);

  const toggleSelected = (id: ResourceId) => {
    if ((selected as any)[id] === true) {
      setSelected(Object.assign({}, selected, { [id]: false }));
    } else {
      setSelected(Object.assign({}, selected, { [id]: true }));
    }

  };

  const selectedCount = Object.keys(selected).filter(k => (selected as any)[k] === true).length;
  const selectedLabel = selectedCount > 0
    ? <span>Use Selected <span className="badge badge-pill badge-light">
      {selectedCount}</span></span>
    : 'Use Selected';

  return (
    <div className="objective-selection">

      <div className="d-flex justify-content-between mb-2">
        <h4>Select from existing objectives:</h4>
        <button className="btn btn-primary" type="button"
            disabled={Object.keys(selected).length === 0}
            onClick={() => props.onUseSelected(toList())}>{selectedLabel}</button>
      </div>

      <div className="existing-objectives">
        <ObjectiveTree {...props} selected={selected} toggleSelected={toggleSelected}/>
      </div>


      <h4>Or create a new objective:</h4>

      <small className="muted">At the end of the course, my students should be able to...</small>
      <div className="input-group mb-3">
        <input type="text" className="form-control"
          value={text} onChange={e => setText(e.target.value)}/>
        <div className="input-group-append">
          <button className="btn btn-primary" type="button"
            disabled={text.trim() === ''}
            onClick={() => props.onRegisterNewObjective(text)}>Create</button>
        </div>
      </div>

    </div>
  );
};
