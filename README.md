# Foldspace

A download utility to test throughput and duration that leverages configurable, concurrent, multipart downloads.

## Usage

```bash
foldspace <url> <chunk-size-bytes> <max-parallel-requests>
```

For example, to download `$URL` in 5 MB chunks allowing up to 12 parallel requests:

```bash
foldspace $URL 5000000 12
```

**NOTE:** this program does not save the data it downloads, but pipes it to /dev/null.
