# Building the image:

NOTE: Due to an issue with ARM64 architecture causing the GCC segfault, we need to build this on an x86_64 machine. If you're on an M1/M2 Mac, you can use the `--platform=linux/amd64` flag to build for the correct architecture.

> docker build --platform linux/amd64 -t amazon-linux-builder:localdev

This will build a docker image named amazon-linux-builder:localdev that you can run to test. The first time, it'll take a few minutes, after that it'll likely be quick unless you're editing lines at the top of the dockerfile.

# Running the image locally

Run from the root of the repository (where mix.exs is located). Make sure there are no pre-existing
deps or builds e.g. `rm -rf _build deps` or the architecture will not match and the docker build
will fail.

```bash
> docker run -it --workdir /github/workspace -v `pwd`:/github/workspace --rm -e GITHUB_ACTIONS=true -e CI=true amazon-linux-builder:localdev "$(git rev-parse --short HEAD)"
```
