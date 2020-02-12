import * as React from 'react';
import { Image } from '../model';
import { Maybe } from 'tsmonad';

interface ImageSize {
  width: string;
  height: string;
}

type Position = {
  x: number;
  y: number;
}

const fetchImageSize = (src: string): Promise<ImageSize> => {
  const img = new (window as any).Image();
  return new Promise((resolve, reject) => {
    img.onload = () => {
      resolve({ height: img.height, width: img.width });
    };
    img.onerror = (err: any) => {
      reject(err);
    };
    img.src = src;
  });
};


export interface ImageProps {
  attributes: any;
  element: Image;
  editor: any;
  isSelected: boolean;
  isFocused: boolean;
}

export interface ImageState {
  size: Maybe<ImageSize>;
}

export class ImageEditor extends React.Component<ImageProps, ImageState> {

  last : Maybe<Position> = Maybe.nothing();
  fetchSize: boolean;
  down: boolean;

  constructor(props: ImageProps) {
    super(props);
    this.down = false;

    const image = props.element;

    if (image.height === undefined || image.height === 'NaN' || image.height.startsWith('-')) {
      this.state = { size: Maybe.nothing() };
      this.fetchSize = true;
    } else {
      const { height, width } = image;
      this.state = { size: Maybe.just({ height, width }) };
      this.fetchSize = false;
    }

  }

  componentDidMount() {

    if (this.fetchSize) {
      const image = this.props.element;
      fetchImageSize(image.src).then(size => {

        const ar = parseInt(size.height, 10) / parseInt(size.width, 10);

        if (ar > 1.0) {
          if (parseInt(size.height, 10) > 500) {
            size.height = '500';
            size.width = (500 / ar) + '';
          }
          this.setState({ size: Maybe.just(size) });
        } else {
          if (parseInt(size.height, 10) > 500) {
            size.height = '500';
            size.width = (500 * ar) + '';
          }
        }
        this.setState({ size: Maybe.just(size) });


      });
    }

  }

  render() {
    const { editor, element, isFocused } = this.props;
    const image = element;

    const down = () => {
      this.down = true;
    }
    const up = (e: any) => {
      e.preventDefault();
      e.stopPropagation();
      if (this.down) {
        this.down = false;

        //editor.setNodeByKey(node.key, 
        //  { data: mutate<ImageData>(image, { height: this.state.size.height, width: this.state.size.width }) });
      }

    }
    const move = (e: MouseEvent) => {
      if (this.down) {

        const { clientX, clientY } = e;

        this.last.caseOf({
          just: last => {
            const { x, y } = last;
            const xDiff = clientX - x;
            const yDiff = clientY - y;
            this.last = Maybe.just({ x: clientX, y: clientY });

            this.state.size.lift(s => {
              const ar = parseInt(s.height, 10) / parseInt(s.width, 10);

              if (Math.abs(xDiff) > Math.abs(yDiff)) {
                const width = '' + (parseInt(s.width, 10) + xDiff);
                const height = '' + (ar * parseInt(width, 10));
                this.setState({ size: Maybe.just({ height, width }) });
              } else {
                const height = '' + (parseInt(s.height, 10) + yDiff);
                const width = '' + (parseInt(height, 10) / ar);
                this.setState({ size: Maybe.just({ height, width }) });
              }
            });

            
          },
          nothing: () => {
            this.last = Maybe.just({ x: clientX, y: clientY });
          },
        })
      }
    }

    const imageStyle = {
      display: 'block',
      maxWidth: '100%',
      maxHeight: '500px',
      marginLeft: 'auto',
      marginRight: 'auto',
      boxShadow: isFocused ? '0 0 0 2px blue' : 'none',
    };

    const divStyle = {
      position: 'relative',
    } as any;

    const handleStyle = {
      backgroundColor: 'white',
      position: 'absolute',
      padding: '3px',
      bottom: '5px',
      left: '50%',
    } as any;

    const handle = isFocused
      ? <div
        onMouseDown={down}
        onMouseUp={up}
        style={handleStyle}><i className={'fa fa-arrows-alt'} /></div>
      : null;

    const { height, width } = this.state.size.caseOf({
      just: s => s,
      nothing: () => (({ height: undefined, width: undefined }) as any),
    });

    return (
      <div {...this.props.attributes}
        onMouseUp={up}
        onMouseMove={move} >
        <div style={divStyle}>
          <img
            src={image.src}
            style={imageStyle}
            height={height}
            width={width}
          />
          {handle}
        </div>

      </div>
    );
  }
}
