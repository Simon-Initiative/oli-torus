import * as React from 'react';
import { Image } from '../model';
import { Maybe } from 'tsmonad';

interface ImageSize {
  width: string;
  height: string;
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

  lastX = null;
  lastY = null;
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
          this.setState({ size });
        } else {
          if (parseInt(size.height, 10) > 500) {
            size.height = '500';
            size.width = (500 * ar) + '';
          }
        }
        console.log('fetched)');
        console.log(size);
        this.setState({ size });


      });
    }

  }

  render() {
    const { editor, element, isFocused } = this.props;
    const image = element;

    function onChange(event) {
      //editor.setNodeByKey(node.key, { data: mutate<ImageData>(image, { src: event.target.value }) })
    }

    const down = () => {
      this.down = true;
    }
    const up = (e) => {
      e.preventDefault();
      e.stopPropagation();
      if (this.down) {
        this.down = false;

        //editor.setNodeByKey(node.key, 
        //  { data: mutate<ImageData>(image, { height: this.state.size.height, width: this.state.size.width }) });
      }

    }
    const move = (e) => {
      if (this.down) {

        const { clientX, clientY } = e;
        if (this.lastX === null) {
          this.lastX = clientX;
          this.lastY = clientY;
        } else {

          const xDiff = clientX - this.lastX;
          const yDiff = clientY - this.lastY;
          this.lastX = clientX;
          this.lastY = clientY;
          const ar = parseInt(this.state.size.height, 10) / parseInt(this.state.size.width, 10);

          if (Math.abs(xDiff) > Math.abs(yDiff)) {
            const width = '' + (parseInt(this.state.size.width, 10) + xDiff);
            const height = '' + (ar * parseInt(width, 10));
            this.setState({ size: { height, width } });
          } else {
            const height = '' + (parseInt(this.state.size.height, 10) + yDiff);
            const width = '' + (parseInt(height, 10) / ar);
            this.setState({ size: { height, width } });
          }

        }
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

    const height = this.state.size === null
      ? undefined : this.state.size.height;
    const width = this.state.size === null
      ? undefined : this.state.size.width;

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
