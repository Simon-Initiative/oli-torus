import * as React from 'react';
import { stringToColor } from 'utils/colors';

export const isImage = (mimeType: string) => {
  return mimeType.match(/^image\//);
};

export const getFileExtensionColor = (extension: any) => {
  return (
    (
      {
        css: '#F438D6',
        js: '#F2D300',
        doc: '#012BAA',
        htm: '#4928CF',
        img: '#8e44ad',
        get png() {
          return this.img;
        },
        get jpg() {
          return this.img;
        },
        get jpe() {
          return this.img;
        },
        pdf: '#D11D00',
        ppt: '#FF9937',
        txt: '#009CF2',
        xls: '#00A51C',
        zip: '#515151',
      } as any
    )[extension] || stringToColor.hex(extension)
  );
};

export const getFileExtensionGlyph = (extension: any) => {
  return (
    (
      {
        txt: (
          <g id={'Layer_1'}>
            <path
              d={'M163.834,427 L393.834,427 L393.834,452 L163.834,452 L163.834,427 z'}
              fill="#DDDDDD"
            />
            <path
              d={`M163.834,378.316 L393.834,378.316 L393.834,403.316 L163.834,403.316 \
          L163.834,378.316 z`}
              fill="#DDDDDD"
            />
            <path
              d={`M163.834,331.023 L393.834,331.023 L393.834,356.023 L163.834,356.023 \
          L163.834,331.023 z`}
              fill="#DDDDDD"
            />
            <path
              d={`M163.834,283.73 L393.834,283.73 L393.834,308.73 L163.834,308.73 \
          L163.834,283.73 z`}
              fill="#DDDDDD"
            />
            <path
              d={`M163.834,236.437 L393.834,236.437 L393.834,261.437 L163.834,261.437 \
          L163.834,236.437 z`}
              fill="#DDDDDD"
            />
          </g>
        ),
        ppt: (
          <g id={'Layer_1'}>
            <path
              d={'M165.888,432 L165.888,370.723 L226.126,370.723 L226.126,432 L165.888,432 z'}
              fill="#DDDDDD"
            />
            <path
              d={'M247.128,432 L247.128,313.152 L307.366,313.152 L307.366,432 L247.128,432 z'}
              fill="#DDDDDD"
            />
            <path
              d={'M331.542,432 L331.542,249.937 L391.78,249.937 L391.78,432 L331.542,432 z'}
              fill="#DDDDDD"
            />
          </g>
        ),
        htm: (
          <g id={'Layer_1'}>
            <path
              d={`M237.484,326.874 L237.484,306.333 L146.747,342.414 L146.747,363.49 \
          L237.484,399.392 L237.484,379.03 L171.932,352.952 z`}
              fill="#DDDDDD"
            />
            <path
              d={'M293.57,267.573 L243.914,401 L264.098,401 L313.932,267.573 z'}
              fill="#DDDDDD"
            />
            <path
              d={`M320.184,379.03 L320.184,399.392 L410.921,363.49 L410.921,342.414 \
          L320.184,306.333 L320.184,326.874 L385.736,352.952 z`}
              fill="#DDDDDD"
            />
          </g>
        ),
        doc: (
          <g id={'Layer_1'}>
            <path
              d={'M163.834,426 L393.834,426 L393.834,451 L163.834,451 L163.834,426 z'}
              fill="#DDDDDD"
            />
            <path
              d={`M163.834,377.316 L393.834,377.316 L393.834,402.316 L163.834,402.316 \
          L163.834,377.316 z`}
              fill="#DDDDDD"
            />
            <path
              d={`M297.643,330.023 L393.834,330.023 L393.834,355.023 L307.195,355.023 \
          L297.643,330.023 z`}
              fill="#DDDDDD"
            />
            <path
              d={`M278.17,282.73 L393.834,282.73 L393.834,307.73 L288.393,307.588 \
          L278.17,282.73 z`}
              fill="#DDDDDD"
            />
            <path
              d={`M260.644,235.437 L393.834,235.437 L393.834,260.437 L269.758,260.437 \
          L260.644,235.437 z`}
              fill="#DDDDDD"
            />
            <path
              d={`M209.84,308.797 L225.417,264.915 L225.752,264.915 L240.826,308.797 z \
          M212.353,235.437 L167.131,355.023 L193.594,355.023 L202.973,328.393 L247.693,328.393 \
          L256.737,355.023 L284.037,355.023 L239.318,235.437 z`}
              fill="#DDDDDD"
            />
          </g>
        ),
        js: (
          <g id={'Layer_1'}>
            <path
              d={`M251.642,273.503 L251.642,251.033 L226.163,251.033 Q222.753,251.033 \
          218.439,252.738 Q214.126,254.444 210.414,257.754 Q206.703,261.064 204.095,266.18 \
          Q201.487,271.296 201.487,278.117 L201.487,315.834 Q201.487,320.849 199.481,324.36 \
          Q197.474,327.871 194.666,329.978 Q191.857,332.084 188.647,332.987 Q185.437,333.89 \
          183.23,333.89 L183.23,351.344 Q185.437,351.344 188.647,352.247 Q191.857,353.15 \
          194.666,355.055 Q197.474,356.961 199.481,360.171 Q201.487,363.381 201.487,367.996 \
          L201.487,406.916 Q201.487,413.737 204.095,418.853 Q206.703,423.969 210.414,427.279 \
          Q214.126,430.589 218.439,432.295 Q222.753,434 226.163,434 L251.642,434 L251.642,411.53 \
          L240.809,411.53 Q237.197,411.53 235.091,410.126 Q232.984,408.722 231.781,406.615 \
          Q230.577,404.509 230.276,401.901 Q229.975,399.292 229.975,397.086 L229.975,364.986 \
          Q229.975,358.566 227.668,354.454 Q225.361,350.341 222.251,347.833 Q219.141,345.325 \
          215.731,344.222 Q212.32,343.118 210.113,342.918 L210.113,342.316 Q212.32,342.115 \
          215.731,341.112 Q219.141,340.109 222.251,337.601 Q225.361,335.094 227.668,330.58 \
          Q229.975,326.066 229.975,318.643 L229.975,288.148 Q229.975,285.741 230.276,283.133 \
          Q230.577,280.525 231.781,278.418 Q232.984,276.311 235.091,274.907 Q237.197,273.503 \
          240.809,273.503 z`}
              fill="#DDDDDD"
            />
            <path
              d={`M307.415,411.53 L307.415,434 L332.894,434 Q336.304,434 340.618,432.295 \
          Q344.931,430.589 348.643,427.279 Q352.354,423.969 354.962,418.853 Q357.57,413.737 \
          357.57,406.916 L357.57,367.996 Q357.57,363.381 359.577,360.171 Q361.583,356.961 \
          364.391,355.055 Q367.2,353.15 370.41,352.247 Q373.62,351.344 376.027,351.344 \
          L376.027,333.89 Q373.62,333.89 370.41,332.987 Q367.2,332.084 364.391,329.978 \
          Q361.583,327.871 359.577,324.36 Q357.57,320.849 357.57,315.834 L357.57,278.117 \
          Q357.57,271.296 354.962,266.18 Q352.354,261.064 348.643,257.754 Q344.931,254.444 \
          340.618,252.738 Q336.304,251.033 332.894,251.033 L307.415,251.033 L307.415,273.503 \
          L318.249,273.503 Q321.86,273.503 323.966,274.907 Q326.073,276.311 327.276,278.418 \
          Q328.48,280.525 328.781,283.133 Q329.082,285.741 329.082,288.148 L329.082,318.643 \
          Q329.082,326.066 331.389,330.58 Q333.696,335.094 336.806,337.601 Q339.916,340.109 \
          343.326,341.112 Q346.737,342.115 348.944,342.316 L348.944,342.918 Q346.737,343.118 \
          343.326,344.222 Q339.916,345.325 336.806,347.833 Q333.696,350.341 331.389,354.454 \
          Q329.082,358.566 329.082,364.986 L329.082,397.086 Q329.082,399.292 328.781,401.901 \
          Q328.48,404.509 327.276,406.615 Q326.073,408.722 323.966,410.126 Q321.86,411.53 \
          318.249,411.53 z`}
              fill="#DDDDDD"
            />
          </g>
        ),
        get css() {
          return this.js;
        },
        xls: (
          <g id={'Layer_1'}>
            <path
              d={`M145.187,237.133 L224.978,237.133 L224.978,277.028 L145.187,277.028 \
          L145.187,237.133 z`}
              fill="#DDDDDD"
            />
            <path
              d={`M240.067,237.133 L319.858,237.133 L319.858,277.028 L240.067,277.028 \
          L240.067,237.133 z`}
              fill="#DDDDDD"
            />
            <path
              d={`M336.283,237.133 L416.074,237.133 L416.074,277.028 L336.283,277.028 \
          L336.283,237.133 z`}
              fill="#DDDDDD"
            />
            <path
              d={`M144.519,287.731 L224.31,287.731 L224.31,327.627 L144.519,327.627 \
          L144.519,287.731 z`}
              fill="#DDDDDD"
            />
            <path
              d={`M239.399,287.731 L319.19,287.731 L319.19,327.627 L239.399,327.627 \
          L239.399,287.731 z`}
              fill="#DDDDDD"
            />
            <path
              d={`M335.615,287.731 L415.406,287.731 L415.406,327.627 L335.615,327.627 \
          L335.615,287.731 z`}
              fill="#DDDDDD"
            />
            <path
              d={`M143.851,338.122 L223.642,338.122 L223.642,378.018 L143.851,378.018 \
          L143.851,338.122 z`}
              fill="#DDDDDD"
            />
            <path
              d={`M238.732,338.122 L318.523,338.122 L318.523,378.018 L238.732,378.018 \
          L238.732,338.122 z`}
              fill="#DDDDDD"
            />
            <path
              d={`M334.947,338.122 L414.739,338.122 L414.739,378.018 L334.947,378.018 \
          L334.947,338.122 z`}
              fill="#DDDDDD"
            />
            <path
              d={`M143.184,392.491 L222.975,392.491 L222.975,432.386 L143.184,432.386 \
          L143.184,392.491 z`}
              fill="#DDDDDD"
            />
            <path
              d={`M238.064,392.491 L317.855,392.491 L317.855,432.386 L238.064,432.386 \
          L238.064,392.491 z`}
              fill="#DDDDDD"
            />
            <path
              d={`M334.28,392.491 L414.071,392.491 L414.071,432.386 L334.28,432.386 \
          L334.28,392.491 z`}
              fill="#DDDDDD"
            />
          </g>
        ),
        pdf: (
          <g>
            <path
              d={'M173.917,426 L403.917,426 L403.917,451 L173.917,451 L173.917,426 z'}
              fill="#DDDDDD"
            />
            <path
              d={`M173.917,377.316 L403.917,377.316 L403.917,402.316 L173.917,402.316 \
              L173.917,377.316 z`}
              fill="#DDDDDD"
            />
            <path
              d={`M173.917,282.73 L273.886,282.73 L273.886,307.73 L173.917,307.73 \
              L173.917,282.73 z`}
              fill="#DDDDDD"
            />
            <path
              d={`M173.917,235.437 L273.886,235.437 L273.886,260.437 L173.917,260.437 \
              L173.917,235.437 z`}
              fill="#DDDDDD"
            />
            <path
              d={`M173.917,330.023 L273.886,330.023 L273.886,355.023 L173.917,355.023 \
              L173.917,330.023 z`}
              fill="#DDDDDD"
            />
            <path
              d={`M292.083,235.437 L403.917,235.437 L403.917,355.023 L292.083,355.023 \
              L292.083,235.437 z`}
              fill="#DDDDDD"
            />
          </g>
        ),
        zip: (
          <g>
            <path
              d={`M292.3,292.304 C297.823,292.304 302.301,297.353 302.301,303.582 \
          L302.3,366.543 L255.367,366.543 L255.367,303.582 C255.367,297.353 \
          259.844,292.304 265.367,292.304 L292.3,292.304 z M286.856,300.533 L269.652,300.533 \
          C266.125,300.533 263.265,302.825 263.265,305.653 L263.265,334.239 L293.243,334.239 \
          L293.243,305.653 C293.243,302.825 290.384,300.533 286.856,300.533 z`}
              fill="#DDDDDD"
            />
            <path
              d={'M257.254,476 L299.254,476 L299.254,501 L257.254,501 L257.254,476 z'}
              fill="#DDDDDD"
            />
            <path
              d={`M257.254,442.788 L299.254,442.788 L299.254,467.788 L257.254,467.788 \
          L257.254,442.788 z`}
              fill="#DDDDDD"
            />
            <path
              d={`M257.254,410.331 L299.254,410.331 L299.254,435.331 L257.254,435.331 \
          L257.254,410.331 z`}
              fill="#DDDDDD"
            />
            <path
              d={`M257.254,378.92 L299.254,378.92 L299.254,403.92 L257.254,403.92 \
          L257.254,378.92 z`}
              fill="#DDDDDD"
            />
          </g>
        ),
      } as any
    )[extension] || <g />
  );
};
