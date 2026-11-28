-- Deterministic test data and isolation helpers for PostgreSQL test runs.
-- Works with a throwaway container database (preferred) or a shared test env.

-- ─── 1. Safety guard: refuse to run against anything but a test database ────
DO $$ BEGIN
    IF current_database() NOT LIKE '%test%' THEN
        RAISE EXCEPTION 'Refusing to run: database % is not a test database',
            current_database();
    END IF;
END $$;

-- ─── 2. Run-scoped namespace (concurrent CI jobs do not collide) ────────────
-- In PSQL:  \set run_id 'ci-1234'  then use :'run_id' in inserts.
-- For scripts, pass RUN_ID and substitute, e.g. 'qa-ci-1234'.

-- ─── 3. Idempotent seed data (safe to rerun any number of times) ────────────
INSERT INTO customers (id, name, created_at)
VALUES
    ('qa-seed-customer-1', 'QA Seed Customer 1', '2026-01-01T00:00:00Z'),
    ('qa-seed-customer-2', 'QA Seed Customer 2', '2026-01-01T00:00:00Z')
ON CONFLICT (id) DO NOTHING;

INSERT INTO products (id, sku, price_cents)
VALUES
    ('qa-seed-product-1', 'QA-SKU-001', 9900)
ON CONFLICT (id) DO NOTHING;

-- ─── 4. Per-test entity creation with readable, unique ids ─────────────────
CREATE OR REPLACE FUNCTION qa_make_widget(p_run text, p_name text DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v_id uuid := gen_random_uuid();
BEGIN
    INSERT INTO widgets (id, name, size)
    VALUES (v_id, COALESCE(p_name, 'qa-' || p_run || '-widget'), 3);
    RETURN v_id;
END $$;

-- ─── 5. Cleanup by namespace only (never blanket DELETE) ───────────────────
CREATE OR REPLACE FUNCTION qa_cleanup_run(p_run text)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_count bigint;
BEGIN
    DELETE FROM widgets WHERE name LIKE 'qa-' || p_run || '-%';
    GET DIAGNOSTICS v_count = ROW_COUNT;
    -- Extend with other tables created by the suite; order respects FKs.
    RETURN v_count;
END $$;

-- ─── 6. Verification queries used by the suite ────────────────────────────
-- Assert no residue from previous runs (outside the current namespace):
-- SELECT count(*) FROM widgets WHERE name LIKE 'qa-%' AND name NOT LIKE 'qa-'||:'run_id'||'-%';

-- ─── 7. Optional: transactional rollback pattern for integration tests ────
-- Framework-level equivalent (Python/SQLAlchemy):
--   conn = engine.connect(); tx = conn.begin(); session = Session(bind=conn)
--   yield session; session.close(); tx.rollback(); conn.close()
-- Use this when the suite controls its own session; use the guard + namespace
-- pattern when it cannot (HTTP tests against a live API).

-- ─── Notes ──────────────────────────────────────────────────────────────────
-- * Deterministic timestamps ('2026-01-01T00:00:00Z') make date assertions stable.
-- * Prefer generated data over production snapshots; if snapshots are used,
--   scrub names/emails/phones before loading.
-- * Schedule an orphan sweeper for 'qa-%' rows older than 24h as a safety net;
--   it must never touch non-qa rows.
