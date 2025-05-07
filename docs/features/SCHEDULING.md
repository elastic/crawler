# Scheduling Recurring Crawl Jobs

Crawl jobs can be scheduled to recur.
Scheduled crawl jobs run until terminated by the user.

These schedules are defined through standard cron expressions.
You can use the tool https://crontab.guru to test different cron expressions.

For example, to schedule a crawl job that will execute once every 30 minutes, create a configuration file called `scheduled-crawl.yml` with the following contents:

```yaml
domains:
  - url: "https://example.com"
schedule:
  pattern: "*/30 * * * *" # run every 30th minute
```

Then, use the CLI to then begin the crawl job schedule:

```bash
docker run \
  -v ./scheduled-crawl.yml:/scheduled-crawl.yml \
  -it docker.elastic.co/integrations/crawler:latest jruby bin/crawler schedule /scheduled-crawl.yml
```

**Scheduled crawl jobs from a single execution will not overlap.**

Scheduled jobs will also not wait for existing jobs to complete.
That means if a crawl job is already in progress when another schedule is triggered, the new job will be dropped.
For example, if you have a schedule that triggers at every hour, but your crawl job takes 1.5 hours to complete, the crawl schedule will effectively trigger on every 2nd hour.

**Executing multiple crawl schedules _can_ cause overlap.**

Be wary of executing multiple schedules against the same index.
As with ad-hoc triggered crawl jobs, two crawlers simultaneously interacting with a single index can lead to data loss.
