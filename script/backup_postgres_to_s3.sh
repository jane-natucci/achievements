#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   S3_BUCKET=s3://your-bucket/path \
#   PGHOST=127.0.0.1 \
#   PGPORT=5432 \
#   PGUSER=postgres \
#   PGPASSWORD=secret \
#   ./script/backup_postgres_to_s3.sh
#
# Optional:
#   BACKUP_ROOT=/var/backups/achievements-postgres
#   AWS_S3_CP_ARGS="--storage-class STANDARD_IA"


export S3_BUCKET=s3://achievement-chains/backups
export PGHOST=0.0.0.0
export PGPORT=5432
export PGUSER=postgres

timestamp="$(date -u +"%Y-%m-%dT%H-%M-%SZ")"
backup_root="${BACKUP_ROOT:-/tmp/achievements-postgres-backups}"

if [[ -z "${S3_BUCKET:-}" ]]; then
  echo "S3_BUCKET is required, e.g. s3://my-bucket/achievements-db-backups" >&2
  exit 1
fi

databases=(
  "achievements_production"
  "achievements_production_cable"
  "achievements_production_cache"
  "achievements_production_queue"
)

backup_dir="${backup_root}/${timestamp}"
mkdir -p "${backup_dir}"

cleanup() {
  rm -rf "${backup_dir}"
}

trap cleanup EXIT

for db_name in "${databases[@]}"; do
  output_file="${backup_dir}/${db_name}.dump"

  echo "Backing up ${db_name}..."
  pg_dump \
    --format=custom \
    --no-owner \
    --no-privileges \
    --file="${output_file}" \
    "${db_name}"

  echo "Uploading ${db_name} to ${S3_BUCKET%/}/${timestamp}/..."
  aws s3 cp \
    ${AWS_S3_CP_ARGS:-} \
    "${output_file}" \
    "${S3_BUCKET%/}/${timestamp}/${db_name}.dump"
done

echo "Backup completed for ${#databases[@]} databases at ${timestamp}"