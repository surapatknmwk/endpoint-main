-- ===================================================
-- Grant Order endpoints to all existing roles
-- (without these rows the SecurityFilter's permission check rejects the
--  call with 401 and the webapp logs the operator out)
-- Run after the roles exist. Safe to run more than once: existing
-- providers/permissions are reused.
-- ===================================================

INSERT INTO providers (method, api, status, created_at, created_by)
SELECT v.method, v.api, 'A', now(), 'system'
FROM (VALUES
        ('POST',   '/endpoint-core-service/api/orders'),
        ('PUT',    '/endpoint-core-service/api/orders/{orderId}'),
        ('PATCH',  '/endpoint-core-service/api/orders/complete/{orderId}'),
        ('PATCH',  '/endpoint-core-service/api/orders/cancel/{orderId}'),
        ('DELETE', '/endpoint-core-service/api/orders/{orderId}')
     ) AS v(method, api)
WHERE NOT EXISTS (
    SELECT 1 FROM providers p WHERE p.method = v.method AND p.api = v.api
);

INSERT INTO permissions (role_id, provider_id, status, created_at, created_by)
SELECT r.role_id, p.provider_id, 'A', now(), 'system'
FROM providers p
CROSS JOIN roles r
WHERE p.api LIKE '/endpoint-core-service/api/orders%'
  AND NOT EXISTS (
    SELECT 1 FROM permissions x WHERE x.role_id = r.role_id AND x.provider_id = p.provider_id
);
