# nr-legacy-data-apis

Pilot project code for exposing legacy on-prem Oracle and SQL Server data through containerized data APIs.

## What is in this repo

- Oracle Database Free for local development and seeded sample data
- Oracle REST Data Services (ORDS) for Oracle AutoREST and Database API endpoints
- DB2REST for Oracle-backed REST/OpenAPI exploration
- Microsoft Data API Builder (DAB) container wiring for SQL Server on-prem scenarios
- HTTP requests and PowerShell validation scripts for smoke testing

## Current status

- Oracle local stack is defined in [docker-compose.yml](./docker-compose.yml)
- Oracle seed data is created by [oracle/initdb/001_seed_legacy_app.sh](./oracle/initdb/001_seed_legacy_app.sh)
- ORDS AutoREST enablement SQL is provided in [oracle/enable-ords-rest.sql](./oracle/enable-ords-rest.sql)
- Manual endpoint checks are captured in [test.http](./test.http)
- Automated DB2REST smoke validation is provided in [scripts/test-db2rest.ps1](./scripts/test-db2rest.ps1)
- DAB is currently a starter configuration only; [dab/dab-config.json](./dab/dab-config.json) has no entities configured yet

## Seeded Oracle objects

The first Oracle container initialization creates a `LEGACY_APP` schema with sample data in:

- `CUSTOMERS`
- `WORK_ORDERS`
- `FIELD_SITES`

`FIELD_SITES` includes an Oracle `MDSYS.SDO_GEOMETRY` column and a companion `LOCATION_GEOJSON` column for API validation.

## API behavior captured by this repo

- DB2REST exposes Oracle tables and publishes an OpenAPI 3 document
- DB2REST v1.6.8 does not cleanly serialize raw Oracle `SDO_GEOMETRY` in this proof of concept, so the tests use `LOCATION_GEOJSON`
- ORDS successfully exposes the same Oracle spatial data as structured JSON from the raw `SDO_GEOMETRY` column

## Quick start

1. Copy `.env.example` to `.env` and replace the default passwords.
2. Make sure you can pull the ORDS image from Oracle Container Registry.
3. Start the stack:

```powershell
docker compose up -d oracle-free ords db2rest dab
```

4. After Oracle and ORDS are running, execute [oracle/enable-ords-rest.sql](./oracle/enable-ords-rest.sql) once to enable the sample tables for ORDS AutoREST.
5. Use [test.http](./test.http) for manual checks.
6. Optionally run the DB2REST smoke test:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-db2rest.ps1
```

## Default local ports

- Oracle listener: `1522` on the host
- ORDS: `8080`
- DB2REST: `8081`
- DAB: `5000`

## Security and source control

This repo intentionally does not track local runtime secrets or generated ORDS artifacts such as:

- `.env`
- ORDS wallets
- generated ORDS pool configuration
- self-signed certificates and private keys

ORDS runtime configuration under `ords/config/` is expected to be generated locally at startup and should not be committed.
