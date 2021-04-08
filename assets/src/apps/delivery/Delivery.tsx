import React from 'react';

export interface DeliveryProps {
  resourceId: number;
  sectionSlug: string;
  userId: number;
  pageSlug: string;
}

export const Delivery : React.FunctionComponent<DeliveryProps> = (props: DeliveryProps) => {
  return (
    <div>
      <h3>Advanced Delivery Mode</h3>

      <table className="table table-sm">
        <thead>
          <tr>
            <th>Attribute</th><th>Value</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>Resource Id:</td><td>{props.resourceId}</td>
          </tr>
          <tr>
            <td>Resource Slug:</td><td>{props.pageSlug}</td>
          </tr>
          <tr>
            <td>User Id:</td><td>{props.userId}</td>
          </tr>
          <tr>
            <td>Section Slug:</td><td>{props.sectionSlug}</td>
          </tr>
        </tbody>
      </table>
    </div>
  );
};
