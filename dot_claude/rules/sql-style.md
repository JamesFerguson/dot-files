# SQL / SQL-like formatting (SQL, NRQL, Athena/Presto, CQL, JQL…)

Generate SQL and SQL-like queries pretty-printed, unless the context makes that necessarily ugly (e.g. an inline code span mid-sentence, a single-line config value, a shell one-liner where the quoting cost of newlines exceeds the readability gain). Applies everywhere a human will read the query: chat, dashboards, saved recipes, scripts, docs.

Rules:

- Each clause starts a new line: `SELECT`, `FROM`, `WHERE`, `GROUP BY`, `ORDER BY`, `HAVING`, `LIMIT`, and their dialect cousins (`FACET`, `SINCE`, `UNTIL`, `TIMESERIES`…).
- Repeated subclauses (`AND`, `OR`) each on their own line, indented 2 spaces past their clause.
- Subqueries: newline after the opening `(`; body indented 2 spaces past the indent of the line carrying the `(`; closing `)` on its own line at the same indent as the line carrying the `(`.

Example shape:

```sql
SELECT customer_id, count(*)
FROM orders
WHERE status = 'paid'
  AND total > 100
  AND customer_id IN (
    SELECT id
    FROM customers
    WHERE region = 'AU'
      AND created_at > '2026-01-01'
  )
GROUP BY customer_id
LIMIT 50
```

NRQL accepts newlines fine, including inside dashboard widget definitions (verified 2026-09-10) — "it's going in a widget" is not an exemption.
