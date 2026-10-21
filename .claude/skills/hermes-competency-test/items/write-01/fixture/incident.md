# #inc-2026-10-14-billing — channel export

Exported 2026-10-15 09:12 UTC by Grace Okafor. Times are UTC. Bot messages from `pagerbot`
and `deploybot` are included; reactions and thread-collapse markers are removed.

---

**13:51 deploybot**
checkout-web v2.3.1 rollout started (canary 10% → 100%). Triggered by Lukas Brandt.

**13:55 deploybot**
checkout-web v2.3.1 rollout complete. 24/24 pods healthy.

**13:58 deploybot**
billing-api v4.12.0 pipeline started. Stage 1/3: run pre-deploy migrations against `billing` (pg-billing-01).

**14:02 deploybot**
Migration `0047_add_invoice_lines_customer_idx` started.

**14:03 pagerbot**
:rotating_light: [FIRING] billing-api p99 latency > 5s for 1m (current: 7.8s)

**14:04 pagerbot**
:rotating_light: [FIRING] billing-api 5xx rate > 2% for 1m (current: 6.1%). Paging on-call: Tomás Reyes.

**14:05 Tomás Reyes**
ack, looking. anyone deploying right now?

**14:05 Lukas Brandt**
checkout-web 2.3.1 finished about 10 min ago. it changed the cart retry logic, could be hammering billing?

**14:06 Tomás Reyes**
plausible. checkout-web is the main caller of `POST /v1/invoices`. checking request volume

**14:07 Tomás Reyes**
inbound RPS to billing-api is up maybe 15%, not crazy. but latency is through the roof. declaring SEV-2, I'm IC for now. Grace can you take comms?

**14:07 Grace Okafor**
on it. status page: "Some customers may see errors at checkout. We're investigating."

**14:08 pagerbot**
:warning: [FIRING] cdn edge-cache hit ratio < 80% (current: 71%)

**14:09 Femi Adeyemi**
the CDN one is the scheduled edge maintenance from the vendor, it's in the change calendar 14:00–15:00. unrelated to billing, I'll silence it.

**14:10 Tomás Reyes**
ok. billing-api logs:

```
2026-10-14T14:09:41Z ERROR billing-api handler=create_invoice err="context deadline exceeded" elapsed=30.001s
2026-10-14T14:09:41Z ERROR billing-api handler=create_invoice err="context deadline exceeded" elapsed=30.000s
2026-10-14T14:09:42Z WARN  billing-api pool=pg-billing in_use=50/50 wait_queue=212
2026-10-14T14:09:42Z ERROR billing-api handler=add_line_item err="context deadline exceeded" elapsed=30.002s
2026-10-14T14:09:43Z INFO  billing-api handler=get_invoice status=200 elapsed=41ms
```

reads look fine, writes are timing out at the 30s deadline. pool is maxed.

**14:11 Lukas Brandt**
want me to roll back checkout-web to 2.3.0 just in case? it's a 3 min rollback

**14:11 Tomás Reyes**
yes, do it, cheap to try

**14:12 Priya Natarajan**
joining. is Redis ok? billing caches tax rates there

**14:13 Femi Adeyemi**
redis-billing: 4% CPU, 0 evictions, latency 0.3ms. it's fine.

**14:15 deploybot**
checkout-web rollback to v2.3.0 complete. 24/24 pods healthy.

**14:17 Tomás Reyes**
no change after rollback. 5xx still ~6%, p99 still pinned at 30s. so not checkout-web. writes only. smells like the database

**14:18 Tomás Reyes**
@Ingrid Halvorsen are you around? need eyes on pg-billing-01

**14:19 Ingrid Halvorsen**
here, connecting

**14:21 Ingrid Halvorsen**
pg_stat_activity on pg-billing-01 shows 340 sessions in `Lock` wait, all on relation `invoice_lines`. INSERT and UPDATE statements. SELECTs are going through.

**14:22 Priya Natarajan**
what's holding the lock?

**14:24 Ingrid Halvorsen**
```
  pid  | state  | wait_event | duration | query
-------+--------+------------+----------+--------------------------------------------------------------
 48213 | active |            | 00:22:07 | CREATE INDEX invoice_lines_customer_id_idx ON invoice_lines (customer_id)
```
it's the billing-api migration. plain CREATE INDEX, not CONCURRENTLY. that takes a SHARE lock on the table, which blocks every write to invoice_lines until the build finishes. invoice_lines is ~180M rows, this won't finish soon.

**14:25 Priya Natarajan**
oh no. that's migration 0047, I wrote it. I tested it on staging where the table is tiny, it took 2 seconds. I forgot the CONCURRENTLY. sorry all.

**14:26 Tomás Reyes**
no blame, we'll sort the process later. Ingrid, can we kill it safely?

**14:27 Ingrid Halvorsen**
yes. cancelling a non-concurrent index build just rolls it back, no partial index left behind, no data touched. the migration will be marked failed in the tracking table and the deploy pipeline will stop at stage 1, which is what we want.

**14:28 Lukas Brandt**
fyi the billing-api v4.12.0 app code doesn't depend on the new index, it was only for a reporting query. so no app breakage from skipping it.

**14:29 Tomás Reyes**
ok. Ingrid, go ahead and cancel it.

**14:31 Ingrid Halvorsen**
```
billing=# SELECT pg_cancel_backend(48213);
 pg_cancel_backend
-------------------
 t
```
cancelled. lock released.

**14:32 deploybot**
billing-api v4.12.0 pipeline FAILED at stage 1/3: migration `0047_add_invoice_lines_customer_idx` cancelled. No new pods rolled out; v4.11.3 still serving.

**14:33 Ingrid Halvorsen**
lock waits draining. 340 → 61 → 0 over about a minute.

**14:36 Tomás Reyes**
5xx rate down to 1.2% and falling. pool at 18/50. p99 back under 2s.

**14:38 Grace Okafor**
status page: "A fix has been applied and checkout is recovering. We're monitoring."

**14:41 Priya Natarajan**
there's a backlog of retried invoice writes from checkout-web's retry queue, that's why errors aren't at zero yet. should clear in a few minutes.

**14:49 Tomás Reyes**
error rate back at baseline (0.1%), p99 420ms, retry queue empty. calling it mitigated. customer impact window: 14:02–14:49 UTC, 47 minutes.

**14:50 Grace Okafor**
status page: "Resolved. Checkout errors between 14:02 and 14:49 UTC have stopped. Some customers may have needed to retry their order."

**14:52 Femi Adeyemi**
for the record, the CDN maintenance alert cleared on its own at 14:47. still unrelated.

**14:55 Lukas Brandt**
should I re-deploy checkout-web 2.3.1? it was never the problem

**14:56 Tomás Reyes**
yes, go ahead, but after 16:00 so we're not changing two things in the same hour.

**15:20 Priya Natarajan**
impact numbers from the billing-api access logs: 3,084 requests returned 504 during the window. checkout-web retried most of them automatically; 212 distinct customers saw the "payment couldn't be completed" page at least once. no duplicate charges: the invoice writes are idempotent on the order id.

**15:24 Grace Okafor**
thanks. support has 9 tickets so far, all "checkout failed, worked on retry".

**16:12 deploybot**
checkout-web v2.3.1 rollout complete. 24/24 pods healthy. Triggered by Lukas Brandt.

**21:58 Ingrid Halvorsen**
running the index build for real, off-peak, this time with `CREATE INDEX CONCURRENTLY invoice_lines_customer_id_idx ON invoice_lines (customer_id);` writes are unaffected, I'm watching it.

**22:41 Ingrid Halvorsen**
concurrent build finished in 43 min, index valid. marked 0047 as applied in the migrations table by hand.

---

## Wrap-up (posted 2026-10-15 09:05 by Tomás Reyes, IC)

**Summary.** SEV-2. From 14:02 to 14:49 UTC (47 minutes), about 6% of writes to billing-api failed with
504s and checkout was degraded for some customers. Reads were unaffected.

**Root cause.** Migration `0047_add_invoice_lines_customer_idx`, run automatically by the billing-api
v4.12.0 deploy pipeline, used a plain `CREATE INDEX` on `invoice_lines` (~180M rows). A non-concurrent
index build holds a SHARE lock that blocks all writes to the table until it finishes. Staging didn't
catch it because staging's `invoice_lines` is tiny.

**What didn't cause it.** The checkout-web v2.3.1 deploy (rolled back at 14:15 with no effect, re-deployed
at 16:12), Redis, and the CDN maintenance alert. All were ruled out during the incident.

**Mitigation.** Ingrid cancelled the index build with `pg_cancel_backend(48213)` at 14:31. The lock was
released, queued writes drained, and the billing-api v4.12.0 deploy stopped at the migration stage, so
v4.11.3 kept serving. The index was later built with `CREATE INDEX CONCURRENTLY` off-peak (done 22:41).

**Impact.** 3,084 requests got HTTP 504. 212 customers saw the checkout failure page at least once. No
duplicate charges and no data loss. 9 support tickets.

**Action items.**

| ID | Action | Owner | Due |
|---|---|---|---|
| AI-1 | Add a migration linter (squawk) to billing-api CI that fails any non-concurrent `CREATE INDEX` on existing tables | Priya Natarajan | 2026-10-21 |
| AI-2 | Alert when any Postgres session waits on a lock for more than 30 s on pg-billing-01 | Ingrid Halvorsen | 2026-10-24 |
| AI-3 | Split schema migrations out of the deploy pipeline into a separate, manually approved step for tables over 10M rows | Tomás Reyes | 2026-11-04 |
| AI-4 | Load staging's `invoice_lines` with a production-sized synthetic dataset so migration timing is realistic | Femi Adeyemi | 2026-11-15 |

AI-1 is the priority: it is the only item that would have stopped this exact failure before it shipped.
