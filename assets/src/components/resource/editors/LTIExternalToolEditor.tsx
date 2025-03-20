import React from 'react';
import { LoadingSpinner } from 'components/common/LoadingSpinner';
import { LoaderStatus, useLoader } from 'components/hooks/useLoader';
import { Alert } from 'components/misc/Alert';
import { LTIExternalTool } from 'data/content/resource';
import { getLtiExternalToolDetails } from 'data/persistence/lti_platform';
import { EditorProps } from './createEditor';

interface LTIExternalToolEditorProps extends EditorProps {
  contentItem: LTIExternalTool;
}

export const LTIExternalToolEditor = (props: LTIExternalToolEditorProps) => {
  const { contentItem } = props;

  const [ltiToolDetailsLoader, _] = useLoader(() =>
    getLtiExternalToolDetails(contentItem.clientId).then((result) => {
      if (result.type === 'Ok') {
        return result.result;
      } else {
        throw new Error(result.message);
      }
    }),
  );

  if (ltiToolDetailsLoader.status === LoaderStatus.LOADING) {
    return <LoadingSpinner />;
  }

  if (ltiToolDetailsLoader.status === LoaderStatus.FAILURE) {
    return <Alert variant="error">Error loading LTI details</Alert>;
  }

  const ltiToolDetails = ltiToolDetailsLoader.result;

  return (
    <div className="flex flex-col">
      <div className="m-[20px] p-[20px]">LTI Tool: {ltiToolDetails.name}</div>

      <div>
        <LTIExternalToolWindow launchParams={ltiToolDetails.launch_params} />
      </div>
    </div>
  );
};

type LTIExternalToolWindowProps = {
  launchParams: Record<string, string>;
};

const LTIExternalToolWindow = ({ launchParams }: LTIExternalToolWindowProps) => {
  return (
    <div className="mt-3" style={{ height: 600 }}>
      <form action={launchParams.login_url} className="hide" method="POST" target="tool_content">
        {Object.keys(launchParams)
          .filter((param) => param != 'login_url')
          .map((param) => (
            <input
              key={param}
              type="hidden"
              name={param}
              id={param}
              value={launchParams[param]}
            ></input>
          ))}

        <div style={{ marginBottom: 20 }}>
          <button className="btn btn-primary" type="submit">
            Launch LTI 1.3 Tool
          </button>
        </div>
      </form>
      <iframe
        src="about:blank"
        name="tool_content"
        className="tool_launch w-full h-full"
        allowFullScreen={true}
        tabIndex={0}
        title="Tool Content"
        allow="geolocation *; microphone *; camera *; midi *; encrypted-media *; autoplay *"
        data-lti-launch="true"
      ></iframe>
    </div>
  );
};
