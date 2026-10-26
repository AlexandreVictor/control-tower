#!/usr/bin/env bash
# Concede ao service principal do Databricks App "minha-torre" o acesso de
# leitura ao lakehouse, para as queries do Projeto Farol rodarem no warehouse.
#
# Uso:
#   bash scripts/conceder-acesso.sh [perfil] [warehouse_id]
#
# Padrão: perfil DEFAULT (o único cadastrado) e o primeiro warehouse do workspace.
set -euo pipefail

PERFIL="${1:-DEFAULT}"
WAREHOUSE="${2:-}"
APP="minha-torre"
CATALOGO="lakehouse_vertice"
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v databricks >/dev/null 2>&1; then
  echo "databricks CLI não encontrada no PATH" >&2
  exit 1
fi

echo "→ lendo o service principal do app ${APP} (perfil ${PERFIL})"
SP_CLIENT_ID="$(
  databricks apps get "${APP}" --profile "${PERFIL}" -o json |
    python3 -c 'import json, sys; print(json.load(sys.stdin).get("service_principal_client_id") or "")'
)"

if [ -z "${SP_CLIENT_ID}" ]; then
  echo "não achei service_principal_client_id." >&2
  echo "rode primeiro: databricks bundle deploy --profile ${PERFIL}" >&2
  exit 1
fi
echo "  service principal: ${SP_CLIENT_ID}"

SQL_FILE="$(mktemp /tmp/conceder-acesso.XXXXXX.sql)"
trap 'rm -f "${SQL_FILE}"' EXIT

cat > "${SQL_FILE}" <<EOF
-- Acesso do app ${APP} (SP ${SP_CLIENT_ID}) ao lakehouse do Projeto Farol.
GRANT USE CATALOG ON CATALOG ${CATALOGO} TO \`${SP_CLIENT_ID}\`;
GRANT USE SCHEMA, SELECT ON SCHEMA ${CATALOGO}.gold TO \`${SP_CLIENT_ID}\`;
GRANT USE SCHEMA, SELECT ON SCHEMA ${CATALOGO}.silver TO \`${SP_CLIENT_ID}\`;
EOF

echo "→ concedendo permissões em ${CATALOGO}.{gold,silver}"
ARGS=("${SQL_FILE}" --profile "${PERFIL}")
if [ -n "${WAREHOUSE}" ]; then
  ARGS+=(--warehouse "${WAREHOUSE}")
fi
python3 "${RAIZ}/scripts/run_sql.py" "${ARGS[@]}"

echo "→ ok. agora rode: databricks apps deploy --profile ${PERFIL}"
