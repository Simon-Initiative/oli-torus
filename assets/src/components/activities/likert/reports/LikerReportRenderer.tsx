import React, { useEffect, useState } from 'react';
import { VegaLite, VisualizationSpec } from 'react-vega';
import { makeRequest } from 'data/persistence/common';

export interface LikerReportRendererProps {
  sectionId: string;
  activityId: string;
}

export type ReportData = {
  type: 'success';
  spec: VisualizationSpec;
  prompts: string;
  parent: { title: string; slug?: string };
};

export const LikerReportRenderer = (props: LikerReportRendererProps) => {
  const [reportData, setReportData] = useState<ReportData>();
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string>();

  useEffect(() => {
    const url = `/activity/report/${props.sectionId}/${props.activityId}`;
    setIsLoading(true);
    makeRequest<ReportData>({
      url,
      method: 'GET',
    })
      .then((result) => {
        if (result.type === 'success') {
          setReportData(result);
        } else {
          setError(result.message ? result.message : 'Error: unable to load report');
        }
        setIsLoading(false);
      })
      .catch((e: any) => {
        setIsLoading(false);
        setError(e.message);
      });
  }, []);

  return (
    <div>
      {reportData && (
        <div>
          <VegaLite spec={reportData.spec} actions={false} />
          <div dangerouslySetInnerHTML={{ __html: reportData.prompts }}></div>
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
      {error && <div>Error: {error}</div>}
    </div>
  );
};
