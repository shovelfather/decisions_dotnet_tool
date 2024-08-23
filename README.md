# Decisions dotnet trace / dump script

## Prerequisites

- internet access from the server the script is to be run on
- root access to the server
- `dotnet` installed and on `PATH`
- a working installation of **Decisions**.

## General Usage

Below is an example of general use: taking a 5 minute `dotnet-trace` against a
**Decisions** server running on pid 14325 with a non-empty
`${DECISIONS_FILESTORAGELOCATION}`.

```bash
./decisions_dotnet_tool.sh --pid 14325 dotnet-trace
```

After the trace is done, the output can be found at
`${DECISIONS_FILESTORAGELOCATION}/dotnet/dotnet-trace-data/<TIMESTAMP>`.

To take a full memory dump instead, run

```bash
./decisions_dotnet_tool.sh --pid 14325 dotnet-dump
```

For more information on parameter defaults and option usage, consult the usage
message and help text from: 

```bash
./decisions_dotnet_tool.sh --help
```
