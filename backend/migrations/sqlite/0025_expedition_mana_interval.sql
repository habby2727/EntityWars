-- Preserve accrued mana under the old interval, then extend the current interval to two hours.
UPDATE expedition_balances
SET mana = MIN(6, mana + CASE WHEN regen_at <= unixepoch() * 1000 THEN CAST((unixepoch() * 1000 - regen_at) / 1800000 AS INTEGER) + 1 ELSE 0 END),
    regen_at = CASE WHEN mana + CASE WHEN regen_at <= unixepoch() * 1000 THEN CAST((unixepoch() * 1000 - regen_at) / 1800000 AS INTEGER) + 1 ELSE 0 END >= 6 THEN 0
      ELSE regen_at + (CASE WHEN regen_at <= unixepoch() * 1000 THEN CAST((unixepoch() * 1000 - regen_at) / 1800000 AS INTEGER) + 1 ELSE 0 END) * 1800000 + 5400000 END
WHERE mana < 6 AND regen_at > 0;
