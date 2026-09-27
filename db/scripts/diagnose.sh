#!/usr/bin/env bash
# วิธีใช้: cd db/scripts && bash diagnose.sh
# เช็คว่า migration ลงจริงหรือยัง + checkpoint state + จำนวนแถวใน table เป้าหมาย
set -uo pipefail

DB_URL="${DB_URL:-postgresql://admin:admin123@localhost:5433/endpoint_db}"

echo "==================== 1) DB connection + tables ===================="
psql "$DB_URL" -c "\dt districts subdistricts provinces district_distances subdistrict_distances" 2>&1

echo
echo "==================== 2) districts.lat / subdistricts.lat populated? ===================="
psql "$DB_URL" -c "SELECT count(*) AS total, count(lat) AS with_lat FROM districts;" 2>&1
psql "$DB_URL" -c "SELECT count(*) AS total, count(lat) AS with_lat FROM subdistricts;" 2>&1

echo
echo "==================== 3) row counts in the distance tables ===================="
psql "$DB_URL" -c "SELECT count(*) FROM district_distances;" 2>&1
psql "$DB_URL" -c "SELECT count(*) FROM subdistrict_distances;" 2>&1

echo
echo "==================== 4) local checkpoint files (may be stale vs DB above) ===================="
for f in .cache/*.checkpoint.json; do
  if [ -f "$f" ]; then
    count=$(python3 -c "import json;print(len(json.load(open('$f'))['done']))" 2>/dev/null || echo "?")
    echo "$f -> $count code(s) marked done"
  fi
done

echo
echo "==================== 5) env vars the script will actually use ===================="
echo "DB_HOST=${DB_HOST:-<not set, default localhost>}"
echo "DB_PORT=${DB_PORT:-<not set, default 5433>}"
echo "DB_NAME=${DB_NAME:-<not set, default endpoint_db>}"
echo "DB_USER=${DB_USER:-<not set, default admin>}"

echo
echo "==================== done -- copy everything above back to Claude ===================="
