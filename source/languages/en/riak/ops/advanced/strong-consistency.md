---
title: Managing Strong Consistency
project: riak
version: 2.0.0+
document: guide
audience: advanced
keywords: [operators, strong-consistency]
---

This document provides information on configuring and monitoring a Riak
cluster's optional [[strong consistency]] subsystem. Documentation for
developers building applications using Riak's strong consistency feature
can be found in [[Using Strong Consistency]], while a more theoretical
treatment can be found in [[Strong Consistency]].

## Minimum Cluster Size

In order to use strong consistency in Riak, **your cluster must consist
of at least three nodes**. If it does not, all strongly consistent
operations will fail. If your cluster is smaller than three nodes, you
will need to [[add more nodes|Adding and Removing Nodes]] and make sure
that strong consistency is [[enabled|Managing Strong
Consistency#Enabling-Strong-Consistency]] in all of them.

## Enabling Strong Consistency

Riak's strong consistency subsystem is disabled by default. You can
enable it in each node's [[configuration files]].

```riakconf
strong_consistency = on
```

Remember that you must [[restart your node|riak Command Line]] for
configuration changes to take effect.

For strong consistency requirements to be applied to specific keys,
those keys must be in [[buckets]] bearing a bucket type with the
`consistent` property set to `true`. More information can be found in
[[Using Bucket Types]].

If you enable strong consistency on all nodes in a cluster with fewer
than three nodes, strong consistency will be **enabled** but not
**active**. Once three nodes with strong consistency enabled are
detected in the cluster, the system will be activated. You can check
on the status of the strong consistency subsystem using the
`[[riak-admin ensemble-status|Managing Strong
Consistency#riak-admin-ensemble-status]]` command.

## Fault Tolerance

Strongly consistent operations in Riak are necessarily less highly
available than eventually consistent operations because strongly
consistent operations can only succeed if a **quorum** of object
replicas are currently reachable. A quorum can be expressed as
N / 2 + 1 (or `n_val` / 2 + 1), meaning 3 replicas if N=5, 4 replicas
if N=7, etc. If N=7 and 4 replicas are unavailable, for example, no
strongly consistent operations on that object can succeed.

While Riak uses an N of 3 by default, bear in mind that **higher values
of N will allow for more fault tolerance**. The table below shows the
number of allowable missing replicas for assorted values of N:

Replicas | Allowable missing replicas
:--------|:--------------------------
3 | 1
5 | 2
7 | 3
9 | 4
15 | 7

### `n_val` Recommendations

Due to the quorum requirements explained above, we recommend that you
use _at least_ N=5 for strongly consistent data. You can set the value
of N, i.e. `n_val`, for buckets [[using bucket types]]. For example, you
can create and activate a bucket type with N set to 5 and strong
consistency enabled---we'll call it `consistent_and_fault_tolerant`---using
the following series of [[commands|riak-admin Command Line]]:

```bash
riak-admin bucket-type create consistent_and_fault_tolerant \
  '{"props": {"consistent":true,"n_val":5}}'
riak-admin bucket-type activate consistent_and_fault_tolerant
```

More on creating and activating bucket types can be found in our
[[bucket types|Using Bucket
Types#Managing-Bucket-Types-Through-the-Command-Line]] documentation.

### Setting `target_n_val`

The `target_n_val` parameter sets the highest `n_val` that you intend to
use in an entire cluster. The purpose of this parameter is to ensure
that so-called "hot spots" don't occur, i.e. that data is never stored
more than once on the same physical node, which can happen in rare cases
if no `target_n_val` is set.

A problem to be aware of if you're using strong consistency is that the
default for `target_n_val` is 4, while our suggested minimum `n_val` for
strongly consistent bucket types is 5. This means that you will need to
raise `target_n_val` if you intend to use an `n_val` over 4 for _any_
bucket type. This setting is not contained in `riak.conf`, and must
instead be set in `advanced.config`. For more information, see our
documentation on [[advanced configuration|Configuration
Files#Advanced-Configuration]].

### Note on Bucket Properties

The `consistent` bucket property is one of two bucket properties,
alongside `[[datatype|Using Data Types]]`, that cannot be changed once a
bucket type has been created.

Furthermore, if `consistent` is set to `true` for a bucket type, you
cannot change the `n_val` for the bucket type once it's been created. If
you attempt to do so, you'll see the following error:

```
Error updating bucket <bucket_type_name>:
n_val cannot be modified for existing consistent type
```

### Fault Tolerance and Cluster Size

From the standpoint of strongly consistent operations, larger clusters
tend to be more fault tolerant. Spreading ensembles across more nodes
will decrease the number of ensembles active on each node and thus
decrease the number of quorums affected when a node goes down.

Imagine a 3-node cluster in which all ensembles are N=3 ensembles. If a
single node goes down, _all_ ensembles will lose quorum and be unable to
function. Strongly consistent operations on the entire keyspace will
fail until the node is brought back online.

Now imagine a 50-node cluster with N=5 ensembles. In this cluster, each
node is involved in only 10% of the total ensembles; if a single node
fails, that failure will thus impact only 10% of ensembles. In addition,
because N is set to 5, that will not impact quorum for _any_ ensemble in
the cluster; two additional node failures would need to occur for quorum
to be lost for any ensemble. And even in the case of three nodes
failing, it is highly unlikely that that failure would impact the same
ensembles; if it did, only those ensembles would become unavailable,
affecting only 10% of the key space, as opposed to 100% in the example
of a 3-node cluster consisting of N=3 ensembles.

These examples illustrate why we recommend higher values for N---again,
at least N=5 and preferably N=7---as well as larger clusters.

### Offline Node Recommendations

In general, strongly consistent Riak is more sensitive to the number of
nodes in the cluster than eventually consistent Riak, due to the quorum
requirements mentioned above. While Riak is designed to withstand a
variety of failure scenarios that remove nodes from the cluster, e.g.
hardware or network failure, we nonetheless recommend that you limit the
number of nodes that you intentionally down or reboot, because having
multiple nodes leave the cluster at once can threaten quorum and thus
affect the viability of some or all strongly consistent operations.

If you're using strong consistency and you do need to reboot multiple
nodes, we recommend rebooting nodes very carefully. Rebooting nodes too
quickly in succession can force the cluster to lose quorum and thus to
be unable to service strongly consistent operations. The best strategy
is to reboot nodes one at a time and wait for each node to rejoin
existing ensembles before continuing to the next node. At any point
in time, the state of currently existing ensembles can be checked using
`[[riak-admin ensemble-status|Managing Strong
Consistency#riak-admin-ensemble-status]]`.

## Performance

If you are running into performance issues, bear in mind that the key
space in a Riak cluster is spread across multiple [[consensus
groups|Strong Consistency#Implementation-Details]], each of which
manages a portion of that key space. Increasing the [[ring
size|Clusters#The-Ring]] means more independent consensus groups, which
can provide for more concurrency and higher throughput, and thus better
performance.

<div class="note">
<div class="title">Note on strong consistency and ring resizing</div>
Strong consistency is currently incompatible with the
<a href="/ops/advanced/ring-resizing">ring resizing</a> feature
available in Riak versions 2.0 and later. Our recommendations concerning
ring size should thus be taken into account prior to cluster creation.
</div>

Adding nodes to your cluster is another means of enhancing the
performance of strongly consistent operations. More information can be
found in [[Adding and Removing Nodes]].

## riak-admin ensemble-status

The `[[riak-admin|riak-admin Command Line#ensemble-status]]` interface
has an `ensemble-status` command that provides insight into the current
status of the consensus subsystem undergirding strong consistency.

Running the command by itself will provide general insight:

```bash
riak-admin ensemble-status
```

If the strong consistency subsystem is not currently enabled, you will
see `Note: The consensus subsystem is not enabled.` in the output of the
command.

If the consensus subsystem is enabled, you will see output like this:

```
============================== Consensus System ===============================
Enabled:     true
Active:      true
Ring Ready:  true
Validation:  strong (trusted majority required)
Metadata:    best-effort replication (asynchronous)

================================== Ensembles ==================================
 Ensemble     Quorum        Nodes      Leader
-------------------------------------------------------------------------------
   root       4 / 4         4 / 4      riak@riak1
    2         3 / 3         3 / 3      riak@riak2
    3         3 / 3         3 / 3      riak@riak4
    4         3 / 3         3 / 3      riak@riak1
    5         3 / 3         3 / 3      riak@riak2
    6         3 / 3         3 / 3      riak@riak2
    7         3 / 3         3 / 3      riak@riak4
    8         3 / 3         3 / 3      riak@riak4
```

### Interpreting ensemble-status Output

The following table provides a guide to `ensemble-status` output:

Item | Meaning
:----|:-------
`Enabled` | Whether the consensus subsystem is enabled on the current node, i.e. whether the `strong_consistency` parameter in <code><a href="/ops/advanced/configs/configuration-files#Strong-Consistency">riak.conf</a></code> has been set to `on`. If this reads `off` and you wish to enable strong consistency, see our documentation on <a href="/dev/advanced/strong-consistency#Enabling-Strong-Consistency">enabling strong consistency</a>.
`Active` | Whether the consensus subsystem is active, i.e. whether there are enough nodes in the cluster to use strong consistency, which requires at least three nodes.
`Ring Ready` | If `true`, then all of the vnodes in the cluster have seen the current <a href="/theory/concepts/clusters#The-Ring">ring</a>, which means that the strong consistency subsystem can be used; if `false`, then the system is not yet ready. If you have recently added or removed one or more nodes to/from the cluster, it may take some time for `Ring Ready` to change.
`Validation` | This will display `strong` if the `tree_validation` setting in <code><a href="/ops/advanced/configs/configuration-files#Strong-Consistency">riak.conf</a></code> has been set to `on` and `weak` if set to `off`.
`Metadata` | This depends on the value of the `synchronous_tree_updates` setting in <code><a href="/ops/advanced/configs/configuration-files#Strong-Consistency">riak.conf</a></code>, which determines whether strong consistency-related Merkle trees are updated synchronously or asynchronously. If `best-effort replication (asynchronous)`, then `synchronous_tree_updates` is set to `false`; if `guaranteed replication (synchronous)` then `synchronous_tree_updates` is set to `true`.
`Ensembles` | This displays a list of all of the currently existing ensembles active in the cluster.<br /><ul><li><code>Ensemble</code> --- The ID of the ensemble</li><li><code>Quorum</code> --- The number of ensemble peers that are either leading or following</li><li><code>Nodes</code> --- The number of nodes currently online</li><li><code>Leader</code> --- The current leader node for the ensemble</li></ul>

### Inspecting Specific Ensembles

The `ensemble-status` command enables you to directly inspect the status
of specific ensembles in a cluster. The IDs for all current ensembles
are displayed in the `Ensembles` section of the `ensemble-status` output
described above.

To inspect a specific ensemble, specify the ID:

```bash
riak-admin ensemble-status <id>
```

The following would inspect ensemble `2`:

```bash
riak-admin ensemble-status 2
```

Below is sample output for a single ensemble:

```
================================= Ensemble #2 =================================
Id:           {kv,0,3}
Leader:       riak@riak2 (2)
Leader ready: true

==================================== Peers ====================================
 Peer  Status     Trusted          Epoch         Node
-------------------------------------------------------------------------------
  1    following    yes             1            riak@riak1
  2     leading     yes             1            riak@riak2
  3    following    yes             1            riak@riak2
```

The table below provides a guide to the output:

Item | Meaning
:----|:-------
`Id` | The ID for the ensemble used internally by Riak, expressed as a 3-tuple. All ensembles are `kv`; the second element names the ring partition for which the ensemble is responsible; and the third element is the `n_val` for the keys for which the ensemble is responsible.
`Leader` | Identifies the ensemble's leader. In this case, the leader is on node `riak@riak2` and is identified as leader `2` on that node.
`Leader ready` | States whether the ensemble's leader is ready to respond to requests. If not, requests to the ensemble will fail.
`Peers` | A list of peer vnodes associated with the ensemble.<br /><ul><li><code>Peer</code> --- The ID of the peer</li><li><code>Status</code> --- Whether the peer is a leader or a follower</li><li><code>Trusted</code> --- Whether the peer's Merkle tree is currently considered trusted or not</li><li><code>Epoch</code> --- The current consensus epoch for the peer. The epoch is incremented each time the leader changes.</li><li><code>Node</code> --- The node on which the peer resides.</li></ul>

## Implementation Details

Strong consistency in Riak is handled by a subsystem called
[`riak_ensemble`](https://github.com/basho/riak_ensemble/tree/feature/add-docs/doc).
This system functions differently from other systems in Riak in a number
of ways, and many of these differences are important for operators
configuring and [[managing strong consistency]].

### Basic Operations

The first major difference is that strongly consistent Riak involves a
different set of operations from [[eventually
consistent|Eventual Consistency]] Riak. In strongly consistent buckets,
there are four types of atomic operations on objects:

* **Get** operations work just as they do against
  non-strongly-consistent keys, but with two crucial differences:
  1. connecting clients are guaranteed to return the most recently
     written value (the **C** in CAP)
  2. reads on strongly consistent keys *never* return siblings, hence
     there is no need for [[conflict resolution]]
* **Conditional put** operations write an object only if no object
  currently exists in that key. The operation will fail if the key
  already exists; if the key was never written or has been deleted, the
  operation succeeds.
* **Conditional modify** operations are compare-and-swap (CAS)
  operations that succeed only if the value of a key has not changed
  since it was previously read.
* **Delete** operations work just as they do against
  non-strongly-consistent keys.

From the standpoint of clients connecting to Riak, there is no
difference between strongly and non-strongly consistent data. The
operations performed on objects---reads, writes, deletes, etc.---are the
same, which means that the client API for strong consistency is
essentially the same, with the important exception of [[error handling|
Using Strong Consistency#Error-Messages]].

### Ensembles

The main actors in Riak's implementation of strong consistency are
**ensembles**, which are independent groups that watch over a portion of
a Riak cluster's key space. In this regard they are somewhat like
[[vnodes|Riak Glossary#vnode]], although with important differences.

Ensembles operate in terms of **quorum** between object replicas,
meaning that strongly consistent operations can succeed only if
`n_val` / 2 + 1 primary replicas of an object are online and reachable.
Thus, 4 replicas must be available in a 7-node cluster, 5 in a 9-node
cluster, etc. If a quorum of replicas cannot be reached, then strongly
consistent operations will fail.

Ensemble behavior can be [[configured|Managing Strong
Consistency#Configuring-Strong-Consistency]] in a variety of ways.

## Configuring Strong Consistency

All of the parameters listed below must be set in each node's
`advanced.config` file, _not_ in `riak.conf`. Information on the syntax
and usage of `advanced.config` can be found in our documentation on
[[advanced configuration|Configuration Files#Advanced-Configuration]],
as well as a full listing of [[strong-consistency-related
parameters|Configuration Files#Strong-Consistency]].

### Leaders, Followers, and Workers

Any ensemble responsible for a portion of the cluster's key space at any
point in time consists of **leaders** and **followers** that coordinate
on most requests. If you wish, leaders can be granted **leases** that
empower them to respond to read requests on their own, without
contacting any followers.

In addition to leaders and followers, any ensemble managing a portion of
the [[key space|Clusters#The-Ring]] in your cluster relies upon
concurrent **workers** to service requests.

#### Leader Behavior

The `trust_lease` setting determines whether leader leases are used to
optimize reads. When set to `true`, a leader with a valid lease can
handle reads directly without needing to contact any followers. When
`false`, the leader will always contact followers. The default is
`true`.

All leaders have periodic duties that they perform, including refreshing
the leader lease. You can determine how frequently this occurs, in
milliseconds, using the `ensemble_tick` setting. The default is 500
milliseconds. This setting must be lower than both `lease_duration` and
`follower_timeout` (both explained below).

If you set `trust_lease` to `true`, you can also specify how long a
leader lease remains valid without being refreshed, using the
`lease_duration` setting, which is specified in milliseconds. This
setting should be higher than `ensemble_tick` to ensure that leaders
have to time to refresh their leases before they time out, and it _must_
be lower than `follower_timeout`. The default is `ensemble_tick` * 3/2,
i.e. if `ensemble_tick` is 400, `lease_duration` will default to 600.

#### Worker Settings

You can choose how many workers are assigned to ensembles using the
`peer_workers` setting. Increasing the number of workers will make the
strong consistency system more computationally expensive but it can
improve performance in some cases, depending on the workload. The
default is `1`.

### Timeouts

You can establish timeouts for both gets and puts, using the
`peer_get_timeout` and `peer_put_timeout` settings, respectively. Both
are expressed in milliseconds and default to 60000 (i.e. 1 minute).

Longer timeouts will decrease the likelihood that get or put operations
will fail; shorter timeouts entail shorter wait times for connecting
clients, but at a greater risk of failed operations.

### Merkle Tree Settings

All peers in Riak's strong consistency system maintain persistent
[Merkle trees](http://en.wikipedia.org/wiki/Merkle_tree) for all data
stored by that peer.

#### Tree Validation

The `tree_validation` parameter determines whether Riak considers Merkle
trees to be trusted after a peer restart. When enabled, i.e. when
`tree_validation` is set to `true` (the default), Riak does not trust
peer trees after a restart, instead requiring the peer to sync with a
trusted majority. While this is the safest mode because it protects Riak
against silent corruption in Merkle trees, it carries the drawback that
it can reduce Riak availability by requiring more than a simple majority
of nodes to be online and reachable.

If you are using ensembles with N=3, we recommend setting
`tree_validation` to `false`.

#### Synchronous vs. Asynchronous Tree Updates

Merkle tree updates can happen synchronously or asynchronously. This is
determined by the `synchronous_tree_updates` parameter. When set to
`false`, which is the default, Riak responds to the client after the
first roundtrip, allowing the Merkle tree update to happen
asynchronously in the background; when set to `true`, Riak requires two
quorum roundtrips to occur before replying back to the client.

Please note that this setting applies only to the metadata writes sent
to followers. Leaders _always_ update their local Merkle trees before
responding to the client. Asynchronous updates can be unsafe in certain
scenarios. For example, if a leader crashes before sending metadata
updates to followers _and_ all followers that had acknowledged the write
somehow revert the object value immediately prior to the write request,
a future read could hypothetically return the immediately preceding
value without realizing that the value was incorrect. Setting
`synchronous_tree_updates` to `false` does bear this possibility, but it
is exceedingly unlikely.

## Monitoring Strong Consistency

Riak provides a wide variety of data related to the current operating
status of a node. This data is available by running the `[[riak-admin
status|Inspecting a Node#riak-admin-status]]` command.

A full listing of these stats is available in [[Inspecting a Node]].
All strong consistency-related stats are prefixed with `consistent_`,
e.g. `consistent_gets`, `consistent_puts`, etc. Most of these stats
are so-called "one-minute stats," meaning that they reflect node
activity in the last minute.

Strong consistency stats fall into two categories: GET-related and
PUT-related stats.

### GET-related stats

Stat | Description
:----|:-----------
`consistent_gets` | Number of strongly consistent GETs coordinated by this node in the last minute
`consistent_gets_total` | Total number of strongly consistent GETs coordinated by this node
`consistent_get_objsize_mean` | Mean object size for strongly consistent GETs on this node in the last minute
`consistent_get_objsize_median` | Median object size for strongly consistent GETs on this node in the last minute
`consistent_get_objsize_95` | 95th-percentile object size for strongly consistent GETs on this node in the last minute
`consistent_get_objsize_99` | 99th-percentile object size for strongly consistent GETs on this node in the last minute
`consistent_get_objsize_100` | 100th-percentile object size for strongly consistent GETs on this node in the last minute
`consistent_get_time_mean` | Mean time between reception of client GETs to strongly consistent keys and subsequent response
`consistent_get_time_median` | Median time between reception of client GETs to strongly consistent keys and subsequent response
`consistent_get_time_95` | 95th-percentile time between reception of client GETs to strongly consistent keys and subsequent response
`consistent_get_time_99` | 99th-percentile time between reception of client GETs to strongly consistent keys and subsequent response
`consistent_get_time_100` | 100th-percentile time between reception of client GETs to strongly consistent keys and subsequent response

### PUT-related stats

Stat | Description
:----|:-----------
`consistent_puts` | Number of strongly consistent PUTs coordinated by this node in the last minute
`consistent_puts_total` | Total number of strongly consistent PUTs coordinated by this node
`consistent_put_objsize_mean` | Mean object size for strongly consistent PUTs on this node in the last minute
`consistent_put_objsize_median` | Median object size for strongly consistent PUTs on this node in the last minute
`consistent_put_objsize_95` | 95th-percentile object size for strongly consistent PUTs on this node in the last minute
`consistent_put_objsize_99` | 99th-percentile object size for strongly consistent PUTs on this node in the last minute
`consistent_put_objsize_100` | 100th-percentile object size for strongly consistent PUTs on this node in the last minute
`consistent_put_time_mean` | Mean time between reception of client PUTs to strongly consistent keys and subsequent response
`consistent_put_time_median` | Median time between reception of client PUTs to strongly consistent keys and subsequent response
`consistent_put_time_95` | 95th-percentile time between reception of client PUTs to strongly consistent keys and subsequent response
`consistent_put_time_99` | 99th-percentile time between reception of client PUTs to strongly consistent keys and subsequent response
`consistent_put_time_100` | 100th-percentile time between reception of client PUTs to strongly consistent keys and subsequent response

## Strong Consistency and Active Anti-Entropy

Riak's [[active anti-entropy]] \(AAE) feature _can_ repair strongly
consistent data. Although it is not necessary to use active anti-entropy
if you are using strong consistency, we nonetheless recommend doing so.

Without AAE, all object conflicts are repaired via [[read
repair|Active Anti-Entropy#Read-Repair-vs.-Active-Anti-Entropy]].
Read repair, however, cannot repair conflicts in so-called "cold data,"
i.e. data that may not be read for long periods of time. While using AAE
does entail small performance losses, not using AAE can lead to problems
with silent on-disk corruption. 

To avoid these problems, you should [[enable active anti-entropy|Managing
Active Anti-Entropy##Enabling-Active-Anti-Entropy]].

## Important Caveats

The following Riak features are not currently available in strongly
consistent buckets:

* [[Secondary indexes|Using Secondary Indexes]]
* [[Riak Data Types|Using Data Types]]
* [[Ring resizing]]

Strongly-consistent writes operate only on single keys. There is
currently no support within Riak for strongly consistent operations
against multiple keys, although it is always possible to incorporate
write and read locks in an application that uses strongly-consistent
Riak.

## Known Issues 

There are a few known issues that you should be aware of when using the
latest version of strong consistency.

* **Consistent reads of never-written keys create tombstones** --- A
  tombstone will be written if you perform a read against a key that a
  majority of peers claims to not exist. This is necessary for certain
  corner cases in which offline or unreachable replicas containing
  partially written data need to be rolled back in the future.
* **Consistent keys and key listing** --- In Riak, key listing
  operations, such as listing all the keys in a bucket, do not filter
  out tombstones. While this is rarely a problem for non-strongly-
  consistent keys, it does present an issue for strong consistency due
  to the tombstone issues mentioned above.
* **Secondary indexes not supported** --- Strongly consistent
  operations do not support [[secondary indexes|Using Strong
  Consistency]] \(2i) at this time. Furthermore, any other metadata
  attached to objects will be silently ignored by Riak.
* **Multi-Datacenter Replication not supported** --- At this time,
  consistent keys are *not* replicated across clusters using [[Multi-
  Datacenter Replication|Multi Data Center Replication: Architecture]]
  \(MDC). This is because MDC replication currently supports only
  eventually consistent replication across clusters. Mixing strongly
  consistent data within a cluster with eventually consistent data
  between clusters is difficult to reason about from the perspective of
  applications. In a future version of Riak, we will add support for
  strongly consistent replication across multiple datacenters/clusters.
* **Client library exceptions** --- Basho's official [[client
  libraries]] convert errors returned by Riak into generic exceptions,
  with a message derived from the returned server-side error message.
  More information on this problem can be found in [[Using Strong
  Consistency|Using Strong Consistency#Error-Messages]].
