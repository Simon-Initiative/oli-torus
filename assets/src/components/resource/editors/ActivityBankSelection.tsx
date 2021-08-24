import React from 'react';
import * as Immutable from 'immutable';
import { ActivityBankSelection as Selection } from 'data/content/resource';
import { LogicBuilder } from 'components/logic/LogicBuilder';
import { TextInput } from 'components/common/TextInput';
import * as Bank from 'data/content/bank';
import { Objective } from 'data/content/objective';
import { ActivityEditorMap } from 'data/content/editors';

export type ActivityBankSelectionProps = {
  selection: Selection;
  onChange: (selection: Selection) => void;
  editMode: boolean;
  allObjectives: Immutable.List<Objective>;
  projectSlug: string;
  onRegisterNewObjective: (objective: Objective) => void;
  editorMap: ActivityEditorMap;
};

export const ActivityBankSelection = (props: ActivityBankSelectionProps) => {
  const { selection, onChange, editMode } = props;

  const onChangeCount = (countString: string) => {
    const count = parseInt(countString, 10);
    const selection = Object.assign({}, props.selection, { count });
    onChange(selection);
  };

  const onChangeLogic = (logic: Bank.Logic) => {
    const selection = Object.assign({}, props.selection, { logic });
    onChange(selection);
  };

  return (
    <div className="">
      <div className="d-flex justify-items-start">
        <span>Number of activities to select:</span>
        <TextInput
          onEdit={onChangeCount}
          type="number"
          editMode={editMode}
          value={selection.count.toString()}
          label="Number of activities"
        />
      </div>
      <LogicBuilder
        allowText={false}
        editMode={editMode}
        logic={selection.logic}
        onChange={onChangeLogic}
        onRegisterNewObjective={props.onRegisterNewObjective}
        allObjectives={props.allObjectives}
        projectSlug={props.projectSlug}
        editorMap={props.editorMap}
        onRemove={() => true}
      />
    </div>
  );
};
