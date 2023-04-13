import * as React from 'react';
import './TestResults.scss';

interface TestResultsProps {
  percentTestsPassed: number;
}

export class TestResults extends React.Component<TestResultsProps, Record<string, never>> {
  constructor(props: TestResultsProps) {
    super(props);
  }

  render() {
    const { percentTestsPassed } = this.props;
    const roundedPercent = Math.round(100 * percentTestsPassed);

    if (isNaN(percentTestsPassed)) {
      return null;
    }

    const text =
      roundedPercent === 100
        ? `${roundedPercent}% of tests passed!`
        : `${100 - roundedPercent}% of tests failed.`;

    return <div className="test-results">{text}</div>;
  }
}
