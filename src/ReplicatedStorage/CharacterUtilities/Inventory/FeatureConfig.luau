--!strict

-- One feature flag controls both the legacy controller entry point and the
-- React inventory surface. Keep the two paths from running simultaneously.
return table.freeze({
	Enabled = false,
})