CREATE TABLE IF NOT EXISTS users (
	id uuid PRIMARY KEY,
	email text UNIQUE NOT NULL,
	display_name text,
	disabled boolean NOT NULL DEFAULT false,
	created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS jobs (
	id uuid PRIMARY KEY,
	type text NOT NULL,
	payload jsonb NOT NULL,
	run_at timestamptz NOT NULL,
	status text NOT NULL,
	attempts integer NOT NULL DEFAULT 0,
	last_error text,
	created_at timestamptz NOT NULL DEFAULT now(),
	updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS jobs_status_run_at_idx ON jobs (status, run_at);
