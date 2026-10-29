# Running Open Crawler as an Elastic Agent component

> [!NOTE]
> Running the crawler under Elastic Agent is a technical preview. The command and the policy format may change.

Open Crawler can run as a component of [Elastic Agent](https://www.elastic.co/docs/reference/fleet).
In this mode Agent starts the crawler, hands it the crawl configuration and the Elasticsearch output from the agent policy, and triggers crawls either on a schedule or through actions.
This is the building block for Elastic-managed (agentless) crawlers.

The crawler speaks the [Elastic Agent V2 control protocol](https://github.com/elastic/elastic-agent-client): Agent spawns the crawler process, writes the connection details to its STDIN and the crawler connects back over gRPC with mutual TLS.
The crawler then keeps checking in with Agent (reporting the state of its units) and listens for actions.

## The `agent` command

```bash
bin/crawler agent [--checkin-interval=SECONDS]
```

The command only works when started by Elastic Agent, because it reads the connection details from STDIN.
Running it from a terminal blocks until STDIN is closed and then fails with `No startup information received from Elastic Agent on STDIN`.

| Option | Default | Description |
|---|---|---|
| `--checkin-interval` | `5` | Seconds between check-ins. Agent marks a component as failed when it does not check in for 30 seconds. |

The process exits with a non-zero status when the connection to Agent is lost, which makes Agent restart it.

## Policy mapping

Agent assigns two kinds of units to the crawler component:

- **Input unit** (`type: crawler`): the crawl configuration. It accepts the same settings as a [crawler.yml](../CONFIG.md) file, including dotted keys such as `elasticsearch.pipeline`. Keys that Agent adds to every input (`id`, `name`, `revision`, `data_stream`, `meta`, `streams`, ...) are ignored, as are unknown settings (a warning is logged for them).
- **Output unit** (`type: elasticsearch`): the Elasticsearch connection. It is translated into the crawler's `elasticsearch` settings:

| Output field | Crawler setting |
|---|---|
| `hosts` (first entry, `http://` is assumed when no scheme is given) | `elasticsearch.host` |
| `api_key` (`id:key` pairs are base64-encoded as Elasticsearch expects) | `elasticsearch.api_key` |
| `username` / `password` | `elasticsearch.username` / `elasticsearch.password` |
| `ssl.verification_mode: none` | `elasticsearch.ssl_verify: false` |
| `ssl.certificate_authorities` (inline PEM or paths) | `elasticsearch.ca_file` |

`elasticsearch.*` settings on the input take precedence over the output, matching the behaviour of `--es-config` on the CLI.
`output_index` is required unless `output_sink` is set to something other than `elasticsearch`.
The log level of the unit is used when the input does not set `log_level`.

When the policy contains a `schedule.pattern`, crawls run on that cron schedule exactly like [`bin/crawler schedule`](SCHEDULING.md).
Without a schedule, crawls only run when requested through an action.

A configuration change received while a crawl is running does not interrupt that crawl; the new configuration is used for the next one.

See [`config/agent/elastic-agent.yml.example`](../../config/agent/elastic-agent.yml.example) for a standalone Agent policy.

## Actions

Agent can send actions to the crawler component. Every action gets exactly one JSON response.

| Action | Result | Failure |
|---|---|---|
| `crawl` | `{"crawl_id": ..., "status": "running", "trigger": "action", "started_at": ...}` | A crawl is already in progress, or the crawler is not configured yet |
| `status` | `{"configured": true, "crawl": {<status of the last crawl or null>}}` | — |
| `stop` | `{"status": "stopping", "crawl_id": ...}` | No crawl is in progress |

Only one crawl runs at a time; a `crawl` action received during a crawl is rejected with `A crawl is already in progress (crawl id: ...)`.
Diagnostics actions are not supported and are answered with a failure.

## Reported state

The crawler reports the state of its units on every check-in:

| State | Meaning |
|---|---|
| `STARTING` | The unit was received but not processed yet |
| `CONFIGURING` | The crawler input is waiting for an Elasticsearch output |
| `HEALTHY` | The configuration is valid; the message describes the schedule or the current crawl |
| `DEGRADED` | The last crawl failed; the message contains the reason |
| `FAILED` | The configuration is invalid, or the unit type is not supported |
| `STOPPED` | Agent asked the unit to stop |

The input unit's payload carries the status of the current or last crawl: `crawl_id`, `status` (`running`, `success` or `failure`), `trigger` (`action` or `schedule`), `started_at`, `finished_at` and `message`.

## Running with a local Elastic Agent

1. Install the crawler and its dependencies (`make install`), or use the Docker image.
2. Copy `config/agent/crawler` and `config/agent/crawler.spec.yml` into the `components` directory of the Elastic Agent installation (for example `data/elastic-agent-<version>/components`). Set `CRAWLER_HOME` in the launcher's environment, or edit it, so that it points at the crawler checkout.
3. Add a `crawler` input and an `elasticsearch` output to the agent policy, see `config/agent/elastic-agent.yml.example`.
4. Restart Elastic Agent. The crawler logs are part of the Agent logs; `elastic-agent status` shows the crawler input as `HEALTHY` once it is configured.

## Limitations

- Only TCP gRPC addresses are supported (the default for Elastic Agent); local socket addresses (`unix://`, `npipe://`) are rejected.
- Check-in chunking is not advertised to Agent.
- Crawl state is kept in memory; a restarted component starts without a crawl history.

## Protocol definitions

The protocol messages are built at runtime from `lib/crawler/agent/proto/elastic-agent-client.textproto`, a descriptor set generated from the upstream `.proto` files.
Regenerate it with `script/agent/generate_descriptor.sh [ref]` (requires `protoc`).
