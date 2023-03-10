import React, { useState } from 'react';
import { AddActivity } from 'components/content/add_resource_content/AddActivity';
import { AddResourceContent } from 'components/content/add_resource_content/AddResourceContent';
import { ActivityEditContext } from 'data/content/activity';
import { ActivityEditorMap } from 'data/content/editors';
import { Objective } from 'data/content/objective';
import { ResourceContent, ResourceContext } from 'data/content/resource';
import { FeatureFlags } from 'apps/page-editor/types';
import { NonActivities } from 'components/content/add_resource_content/NonActivities';

export type AddResourceProps = {
  index: number[];
  isLast?: boolean;
  parents: ResourceContent[];
  editMode: boolean;
  editorMap: ActivityEditorMap;
  resourceContext: ResourceContext;
  featureFlags: FeatureFlags;
  onAddItem: (c: ResourceContent, index: number[], a?: ActivityEditContext) => void;
  onRegisterNewObjective: (objective: Objective) => void;
};

const DEFAULT_TIP = 'Insert a content item or an interactive, scorable question';

export const AddResource = (props: AddResourceProps) => {
  const [tip, setTip] = useState(DEFAULT_TIP);
  const [timer, setTimer] = useState<NodeJS.Timeout | null>(null);

  const onResetTip = () => {
    setTip('');
    if (timer !== null) {
      clearTimeout(timer);
    }
    const handle = setTimeout(() => setTip(DEFAULT_TIP), 5000);
    setTimer(handle);
  };

  const onChangeTip = (tip: string) => {
    setTip(tip);
    if (timer !== null) {
      setTimer(null);
      clearTimeout(timer);
    }
  };

  return (
    <AddResourceContent {...props}>
      <div className="p-2">
        <div className="d-flex flex-row">
          <NonActivities {...props} onSetTip={onChangeTip} onResetTip={onResetTip} />
          <div className="resource-choices-divider" />
          <AddActivity {...props} onSetTip={onChangeTip} onResetTip={onResetTip} />
        </div>
        <div className="mt-2 ml-2" style={{ lineHeight: 0.8, height: 24 }}>
          <small className="resource-choices-tip">{tip}</small>
        </div>
      </div>
    </AddResourceContent>
  );
};
