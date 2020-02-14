import * as ContentModel from 'data/content/model';

export type Attribute = {
  key: string,
  value: string,
};

export type AttributesProps = {
  attributes: Attribute[],
  onEdit: (attribute: Attribute) => void;
}

export const Attributes = (props: AttributesProps) => {
  const rows = props.attributes.map(a => {
    return (
      <div>
        <td>{a.key}</td>
        <td>{a.value}</td>
      </div>
    );
  })
  return (
    <div className="container">
      <div className="row">
        <div className="col">

        </div>
        <div className="col-5">
          2 of 3 (wider)
        </div>
        <div className="col">

        </div>
      </div>
    </div>
  );
}

export function getEditableAttributes(model: ContentModel.ModelElement): Attribute[] {

  const ignoreKeys = {
    id: true,
    type: true,
    children: true,
  } as any;

  return Object.keys(model)
    .filter(k => ignoreKeys[k] === undefined)
    .map(k => ({ key: k, value: model[k] }));

}
