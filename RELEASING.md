# Releasing Assimulo

The release process is manual. The long-term goal is to adopt
[python-semantic-release](https://python-semantic-release.readthedocs.io/) so
that versioning, changelog, tagging, and upload are driven by commit messages.

## Prerequisites

The repository must have a GitHub Actions environment named `pypi`. PyPI must
have a Trusted Publisher configured for the `Assimulo` project bound to this
repository, workflow `wheels.yml`, and environment `pypi`. See the
[PyPI Trusted Publishers documentation](https://docs.pypi.org/trusted-publishers/)
for setup.

## Cutting a release

1. Update the `version:` field in `meson.build`.
2. Prepend a section for the new version to `CHANGELOG`.
3. Commit the changes on the release branch.
4. Create and push the tag:
   ```
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```
5. Run the `Build wheels` workflow via `workflow_dispatch` against the new
   tag with `publish: true`. The `upload_pypi` job runs only when dispatched
   against a `v*` tag. It builds wheels for Linux and Windows and uploads
   them to <https://pypi.org/project/Assimulo/>.
