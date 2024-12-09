# Horizontal scaling

Torus has native support for horizontal scaling (multiple app server instances).

It uses [libcluster](https://github.com/bitwalker/libcluster) for automatic cluster formation (with `Gossip` as default config).

For a single node/instance Torus will work as a common app.

## Configuration

See [.env example](https://github.com/Simon-Initiative/oli-torus/blob/master/oli.example.env) for available environment variables.

Take into account that different strategies could use different config options.

## AWS EC2 support

Torus has support in place for scaling AWS EC2 instances using the [libcluster_ec2 strategy](https://github.com/kyleaa/libcluster_ec2).

A particular EC2 instance tag is applied to instances that you want to cluster. The Torus app will periodically look for instances that have defined the tag,
using the EC2 `describe-instances` API (access to this API should be granted to the EC2 instance profile), and use the discovered instance's IP address to
establish communication between the nodes.

All that is required to join an instance to the cluster is that it have an EC2 instance tag that matches the one defined in the configuration. There is no
particular "parent" node. If the first node that was started fails or goes offline, the remaining nodes are not affected.

For `libcluster-ec2` to work there are some requirements. There are 4 relevant environment variables to configure:

- `LIBCLUSTER_STRATEGY=ClusterEC2.Strategy.Tags` -> This value is static and should always be used.
- `LIBCLUSTER_EC2_STRATEGY_TAG_NAME=TAG_NAME` -> This value reflects the EC2 Instance Tag "Name". It is dynamic and can be different.
- `LIBCLUSTER_EC2_STRATEGY_TAG_VALUE=TAG_VALUE` -> This value reflects the EC2 Instance Tag "Value". It is dynamic and can be different.
- `NODE_COOKIE=SOME_COOKIE` -> This value is used internally by erlang. It is dynamic and can be different.

The instances must have an additional security group that allows them to communicate to each other.

The deployment process must clear out the `.mnesia` folder before a Torus instance starts up. This is not a documented requirement but was found via trial
and error when testing the implementation.

The node name is set via the app [env.sh](https://github.com/Simon-Initiative/oli-torus/blob/master/rel/env.sh.eex) (part of the release) querying the
AWS meta-data endpoint (no special perms need to be granted). By default takes the `$HOSTNAME` var.
