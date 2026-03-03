import React, { Fragment } from 'react';

interface CustomFieldProps {
  uiSchema: any;
  description: string;
  properties: any;
}
const CustomFieldTemplate: React.FC<CustomFieldProps> = (props) => {
  return (
    <Fragment>
      {props.uiSchema['ui:title'] ? (
        <h6 className="custom-field-title">{props.uiSchema['ui:title']}</h6>
      ) : null}
      <div className="grid grid-cols-12 gap-4">
        {props.description}
        {props.properties.map((element: any) => (
          <div
            key={element.content.key}
            className={`${element.content.props.uiSchema.classNames || 'col-span-12'} inner`}
          >
            {element.content}
          </div>
        ))}
      </div>
    </Fragment>
  );
};

export default CustomFieldTemplate;
