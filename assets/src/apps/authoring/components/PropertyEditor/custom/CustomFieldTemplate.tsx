import React, { Fragment } from 'react';

const customFieldTemplate = (props: any) => {
  return (
    <Fragment>
      {props.uiSchema['ui:title'] ? <h6>{props.uiSchema['ui:title']}</h6> : null}
      <div className="row">
        {props.description}
        {props.properties.map((element: any) => (
          <div key={element.content.key}
           className={element.content.props.uiSchema.classNames || 'col-12' }>
            {element.content}
          </div>
        ))}
      </div>
    </Fragment>
  );
};

export default customFieldTemplate;
