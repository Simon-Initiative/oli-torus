import React, { useEffect, useState } from 'react';
import { VegaLite, VisualizationSpec } from 'react-vega';
import { makeRequest } from 'data/persistence/common';

export interface LikerReportRendererProps {
  sectionId: string;
  activityId: string;
  sectionSlug: string;
}

export type Parent = {
  title: string;
  slug?: string;
};

export type Report = {
  type: 'success';
  spec?: VisualizationSpec;
  prompts?: string;
  message?: string;
  parent: Parent;
};

export const LikerReportRenderer = (props: LikerReportRendererProps) => {
  const [report, setReport] = useState<Report>();
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string>();

  useEffect(() => {
    const url = `/activity/report/${props.sectionId}/${props.activityId}`;
    setIsLoading(true);
    makeRequest<Report>({
      url,
      method: 'GET',
    })
      .then((result) => {
        if (result.type === 'success') {
          setReport(result);
        } else {
          setError(result.message ? result.message : 'Error: unable to load report');
        }
      })
      .catch((e: any) => {
        setError(e.message);
      })
      .finally(() => setIsLoading(false));
  }, []);

  return (
    <div>
      {report && (
        <div>
          <div className="container">
            <h3 className="text-center">
              {report.parent.slug ? (
                <a href={`/sections/${props.sectionSlug}/lesson/${report.parent.slug}`}>
                  {report.parent.title}
                </a>
              ) : (
                report.parent.title
              )}
            </h3>
          </div>
          {report.spec && <VegaLite spec={report.spec} actions={false} />}
          {report.prompts && <div dangerouslySetInnerHTML={{ __html: report.prompts }}></div>}
          {report.message && <div>{report.message}</div>}
        </div>
      )}
      {isLoading && (
        <div id="aa-loading">
          <div>report loading</div>
          <div className="loader spinner-border text-primary" role="status">
            <span className="sr-only">Loading...</span>
          </div>
        </div>
      )}
      {error && <div className="alert alert-danger">{error}</div>}
    </div>
  );
};
