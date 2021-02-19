# Contributing to Torus

The following is a set of guidelines for contributing to Torus development. These are mostly guidelines, not rules. Use your best judgment, and feel free to propose changes to this document in a pull request.

#### Table Of Contents

[Code of Conduct](#code-of-conduct)

[What should I know before I get started?](#what-should-i-know-before-i-get-started)
  * [Torus Design Decisions](#design-decisions)

[How Can I Contribute?](#how-can-i-contribute)
  * [Reporting Bugs](#reporting-bugs)
  * [Suggesting Enhancements](#suggesting-enhancements)
  * [Your First Code Contribution](#your-first-code-contribution)
  * [Pull Requests](#pull-requests)

## Code of Conduct

This project and everyone participating in it is governed by the [Torus Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## What should I know before I get started?

### Design Decisions

Documentation regarding Torus architecture and relevant design decisions can be
found in this project's Wiki.

## How Can I Contribute?

### Reporting Bugs

This section guides you through submitting a bug report for Torus. Following these guidelines helps maintainers and the community understand your report, reproduce the behavior, and find related reports.

Before creating bug reports, please check [this list](#before-submitting-a-bug-report) as you might find out that you don't need to create one. When you are creating a bug report, please [include as many details as possible](#how-do-i-submit-a-good-bug-report).

> **Note:** If you find a **Closed** issue that seems like it is the same thing that you're experiencing, open a new issue and include a link to the original issue in the body of your new one.

#### Before Submitting A Bug Report

* You might be able to find the cause of the problem and fix things yourself. Most importantly, check if you can reproduce the problem on the `master` development branch, free from any other
changes that you may have made.  Also, see if you can reproduce the
problem [in the hosted version of Torus](https://proton.oli.cmu.edu), if applicable.
* **Perform a cursory search** to see if the problem has already been reported. If it has **and the issue is still open**, add a comment to the existing issue instead of opening a new one.

#### How Do I Submit A (Good) Bug Report?

Bugs are tracked as [GitHub issues](https://guides.github.com/features/issues/).

Explain the problem and include additional details to help maintainers reproduce the problem:

* **Use a clear and descriptive title** for the issue to identify the problem.
* **Describe the exact steps which reproduce the problem** in as many details as possible. For example, start by explaining how you are accessing Torus, e.g. whether via the hosted instance
or via your own development environment. When listing steps, **don't just say what you did, but explain how you did it**. For example, if you saw a problem after inserting content into a page, explain how you inserted the content, whether you used a keyboard shortcut or used the
mouse to click a toolbar insert button.
* **Provide specific examples to demonstrate the steps**. Include links to files or GitHub projects, or copy/pasteable snippets, which you use in those examples. If you're providing snippets in the issue, use [Markdown code blocks](https://help.github.com/articles/markdown-basics/#multiple-lines).
* **Describe the behavior you observed after following the steps** and point out what exactly is the problem with that behavior.
* **Explain which behavior you expected to see instead and why.**
* **Include screenshots and animated GIFs** which show you following the described steps and clearly demonstrate the problem.  You can use [this tool](https://www.cockos.com/licecap/) to record GIFs on macOS and Windows, and [this tool](https://github.com/colinkeenan/silentcast) or [this tool](https://github.com/GNOME/byzanz) on Linux.

Include details about your configuration and environment:

* **Which browser you are using?**
* **What's the name and version of the OS you're using**?

### Suggesting Enhancements

This section guides you through submitting an enhancement suggestion for Torus, including completely new features and minor improvements to existing functionality. Following these guidelines helps maintainers and the community understand your suggestion and find related suggestions.

#### How Do I Submit A (Good) Enhancement Suggestion?

Enhancement suggestions are tracked as [GitHub issues](https://guides.github.com/features/issues/).

* **Use a clear and descriptive title** for the issue to identify the suggestion.
* **Provide a step-by-step description of the suggested enhancement** in as many details as possible.
* **Provide specific examples to demonstrate the steps**. Include copy/pasteable snippets which you use in those examples, as [Markdown code blocks](https://help.github.com/articles/markdown-basics/#multiple-lines).
* **Describe the current behavior** and **explain which behavior you expected to see instead** and why.
* **Include screenshots and animated GIFs** which help you demonstrate the steps or point out the part of Torus which the suggestion is related to. You can use [this tool](https://www.cockos.com/licecap/) to record GIFs on macOS and Windows, and [this tool](https://github.com/colinkeenan/silentcast) or [this tool](https://github.com/GNOME/byzanz) on Linux.
* **Explain why this enhancement would be useful** to most Torus users and isn't something that can or should be implemented as a third-party Torus learning activity.
* **List some other platforms or applications where this enhancement exists.**

### Your First Code Contribution

#### Local development

Torus can be developed locally. For instructions on how to set up a development environment
see the documentation in the Torus Wiki.

### Pull Requests

Please follow these steps to have your contribution considered by the maintainers:

1. Follow all instructions in the Torus pull request template found in the Torus Wiki
2. Follow the coding conventions and style guide documentation found in the Torus Wiki
3. After you submit your pull request, verify that all [status checks](https://help.github.com/articles/about-status-checks/) are passing <details><summary>What if the status checks are failing?</summary>If a status check is failing, and you believe that the failure is unrelated to your change, please leave a comment on the pull request explaining why you believe the failure is unrelated. A maintainer will re-run the status check for you. If we conclude that the failure was a false positive, then we will open an issue to track that problem with our status check suite.</details>

While the prerequisites above must be satisfied prior to having your pull request reviewed, the reviewer(s) may ask you to complete additional design work, tests, or other changes before your pull request can be ultimately accepted.



