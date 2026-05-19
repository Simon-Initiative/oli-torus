# Document locking

Torus authoring is designed to support only one user editing a document at a time. To
enforce this, the system requires than an exclusive write-lock be obtained prior to
editing a document.

The Torus authoring framework implementation handles obtaining and releasing the write-lock
for a set of documents. This implicit locking approach, as opposed to an explicit approach,
simplifies an activity implementation since the activity implementation does not need to concern
itself with obtaining and releasing locks.

The following sequence diagram overviews the locking implementation.

![locking](assets/locking.png "Locking Implementation")

The important takeaways from the above diagram are:

- The Torus framework for authoring takes care of obtaining and releasing document locks
- An activity implementation can strictly rely on the `editMode` property given to it to determine whether it should enable or disable authoring
