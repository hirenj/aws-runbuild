# Runner for steps from buildspec.yml

We want a few more hooks into the buildspec so that
we can set version numbers / skip builds after doing
a check for remote versions.

This is a simple wrapper script around the buildspec files
that runs the commands for a given step. If there
are files to upload, it does an upload for them.
