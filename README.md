# mdr
Deploy MDR service



### Quotas

| Quota Unit          | Description                             | Example                             |
| ------------------- | --------------------------------------- | ----------------------------------- |
| `1/min/{project}`   | Per-minute quota per GCP project        | 100 requests per minute per project |
| `1/day/{project}`   | Per-day quota per project               | 1000 requests per day per project   |
| `1/min/{user}`      | Per-minute quota per authenticated user | 60 requests per minute per user     |
| `1/day/{user}`      | Per-day quota per authenticated user    | 500 requests per day per user       |
| `1/min/{ip}`        | Per-minute quota per client IP          | 10 requests per minute per IP       |
| `1/day/{ip}`        | Per-day quota per IP                    | 200 requests per day per IP         |
| `1/month/{project}` | Per-month quota per project             | 100,000 requests per month          |
| `1/week/{user}`     | Weekly limit per user                   | 5,000 calls per week per user       |
| `1/hour/{ip}`       | Hourly limit per IP address             | 100 requests per hour per IP        |
