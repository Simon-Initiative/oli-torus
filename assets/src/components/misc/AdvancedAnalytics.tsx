import React, { useState, useEffect, useRef } from 'react';

import { makeRequest } from 'data/persistence/common';
import vegaEmbed from 'vega-embed';

export interface AdvancedAnalyticsProps {
  sectionId: number;
}

type Visualization = {
  id: number;
  title: string;
}

type IndexResult = {
  visualizations: Visualization[];
};

type AnalyticResult = {
  spec: any;
}

function fetchIndex() {
  const params = {
    url: `/viz`,
    method: 'GET'
  };
  return makeRequest<IndexResult>(params);
}

function fetchAnalytic(sectionId: number, analyticId: number) {
  const params = {
    url: `/viz/${analyticId}/${sectionId}`,
    method: 'GET'
  };
  return makeRequest<AnalyticResult>(params);
}

export const AdvancedAnalytics = (props: AdvancedAnalyticsProps) => {
  const { sectionId } = props;
  const [selected, setSelected] = useState<number | null>(null);
  const visRef = useRef(null);

  const [vizzes, setVizzes] = useState([] as Visualization[]);

  useEffect(() => {
    fetchIndex().then(result => {
      console.log(result);
      setVizzes(((result as any) as IndexResult).visualizations);
    })
  }, [])

  const load = (analyticId: number) => {
    setSelected(analyticId);

    console.log('here')
    console.log(sectionId);
    console.log(analyticId);

    fetchAnalytic(sectionId, analyticId)
    .then(results => {
      const spec = (((results as any) as AnalyticResult).spec);
      vegaEmbed((visRef as any).current, spec, { "actions": false })
    });
  };

  return (
    <div id="analytics_select" className="relative flex flex-row text-gray-700 bg-white shadow-md rounded-xl bg-clip-border">
      <nav className="flex min-w-[240px] flex-col gap-1 p-2 font-sans text-base font-normal text-blue-gray-700">
        {vizzes.map((viz) => {
          return (
            <div role="button" onClick={() => load(viz.id)}
              className="flex items-center w-full p-3 leading-tight transition-all rounded-md outline-none #{selected_classes}
              text-start hover:bg-gray-400 hover:bg-opacity-80 focus:bg-blue-gray-50 text-black
              focus:bg-opacity-80 focus:text-blue-gray-900 ">
              {viz.title}
            </div>
          )
        })}
      </nav>
      <div ref={visRef} style={{width: '600px', height: '500px'}} id="graph"/>

    </div>
  );
};
