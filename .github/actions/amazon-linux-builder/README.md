# Building the image:

NOTE: Due to an issue with ARM64 architecture causing the GCC segfault, we need to build this on an x86_64 machine. If you're on an M1/M2 Mac, you can use the `--platform=linux/amd64` flag to build for the correct architecture.

> docker build --platform linux/amd64 -t amazon-linux-builder:localdev

This will build a docker image named amazon-linux-builder:localdev that you can run to test. The first time, it'll take a few minutes, after that it'll likely be quick unless you're editing lines at the top of the dockerfile.

# Running the image locally

A command like this in the root of the torus repo should run it.

Note:

- Edit `/home/projects/oli-torus-1` to an absolute path of wherever your oli-torus is located.
- We're specifying `amazon-linux-builder:localdev` that must match the tag from the build step above.

> docker run --name torusbuildertest --label ef7d85 --workdir /github/workspace --rm -e GITHUB_ACTIONS=true -e CI=true -v "/var/run/docker.sock":"/var/run/docker.sock" -v "/home/runner/work/\_temp/\_github_home":"/github/home" -v "/home/runner/work/\_temp/\_github_workflow":"/github/workflow" -v "/home/runner/work/\_temp/\_runner_file_commands":"/github/file_commands" -v "/home/projects/oli-torus-1":"/github/workspace" amazon-linux-builder:localdev "996927d" build
