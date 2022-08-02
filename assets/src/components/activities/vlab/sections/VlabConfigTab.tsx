import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { MultiInputActions } from 'components/activities/vlab/actions';
import { Dropdown, VlabInput, VlabSchema } from 'components/activities/vlab/schema';
import { Card } from 'components/misc/Card';
import React from 'react';
import { ReactEditor } from 'slate-react';

interface Props {
  editor: ReactEditor & Editor;
}

const configList = ['assignmentPath'];

export const VlabConfigTab: React.FC<Props> = (props) => {
  const { model, dispatch } = useAuthoringElementContext<VlabSchema>();

  return (
    <Card.Card>
      <Card.Title>Vlab Configuration</Card.Title>
      <Card.Content>
        <>
          {configList.map((config, i) => (
            <div key={i}>
              <label>
                <input
                  type="text"
                  name="config"
                  value={model.assignmentPath}
                  onChange={(e) => dispatch(MultiInputActions.setAssignmentPath(e.target.value))}
                />
                {config}
              </label>
            </div>
          ))}
        </>
      </Card.Content>
    </Card.Card>
  );
};
