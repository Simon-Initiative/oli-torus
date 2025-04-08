import React from 'react';
import { LoadingSpinner } from 'components/common/LoadingSpinner';
import { useLoader } from 'components/hooks/useLoader';
import { LTIExternalToolFrame } from 'components/lti/LTIExternalToolFrame';
import { Alert } from 'components/misc/Alert';
import { LTIExternalTool } from 'data/content/resource';
import { getLtiExternalToolDetails } from 'data/persistence/lti_platform';
import { Description, Icon, OutlineItem, OutlineItemProps } from './OutlineItem';
import { EditorProps } from './createEditor';

interface LTIExternalToolEditorProps extends EditorProps {
  contentItem: LTIExternalTool;
}

export const LTIExternalToolEditor = (props: LTIExternalToolEditorProps) => {
  const { contentItem } = props;

  const ltiToolDetailsLoader = useLoader(() => getLtiExternalToolDetails(contentItem.clientId));

  return ltiToolDetailsLoader.caseOf({
    loading: () => <LoadingSpinner />,
    failure: (error) => <Alert variant="error">{error}</Alert>,
    success: (ltiToolDetails) => (
      <div className="flex flex-col">
        <div className="m-[20px] p-[20px]">LTI Tool: {ltiToolDetails.name}</div>

        <div>
          <LTIExternalToolFrame
            launchParams={ltiToolDetails.launch_params}
            resourceId={contentItem.id}
          />
        </div>
      </div>
    ),
  });
};

interface LTIExternalToolOutlineItemProps extends OutlineItemProps {
  contentItem: LTIExternalTool;
}

export const LTIExternalToolOutlineItem = (props: LTIExternalToolOutlineItemProps) => {
  const { contentItem } = props;
  return (
    <OutlineItem {...props}>
      <Icon iconName="fas fa-plug" />
      <Description title="LTI External Tool">{contentItem.clientId}</Description>
    </OutlineItem>
  );
};
