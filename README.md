# Fillmore Labs zerolint Test Cases

[![License](https://img.shields.io/github/license/fillmore-labs/zerolint)](https://www.apache.org/licenses/LICENSE-2.0)

Thus script downloads some open source projects and runs `zerolint -fix` on them.

The projects should be compilable afterwards, but since this can change an API
it should not be applied blindly.

## Usage

Run

```console
./prepare.sh
```

```console
./lint-basic.sh
```

```console
./fix.sh
```

and examine the changes with

```console
./diff.sh
```

afterwards.
