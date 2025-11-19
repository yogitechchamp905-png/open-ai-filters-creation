
locals {
  # ---------------------------------------------------------------------------
  # 0. Define inversion map for severity
  # ---------------------------------------------------------------------------
  severity_inverse_map = {
    "Low"    = "High"
    "High"   = "Low"
    "Medium" = "Medium" # change if needed
  }

  # ---------------------------------------------------------------------------
  # 1. Define all the base filters that should always exist
  # ---------------------------------------------------------------------------
  default_filter_definitions = [
    { name = "Hate",            severity = "Medium", sources = ["Prompt", "Completion"] },
    { name = "Sexual",          severity = "Medium", sources = ["Prompt", "Completion"] },
    { name = "Violence",        severity = "Medium", sources = ["Prompt", "Completion"] },
    { name = "SelfHarm",        severity = "Medium", sources = ["Prompt", "Completion"] },
    { name = "Jailbreak",       severity = "High",   sources = ["Prompt"] },
    { name = "Indirect Attack", severity = "High",   sources = ["Prompt"] }
  ]

  # ---------------------------------------------------------------------------
  # 2. Build default filter template (with severity inversion)
  # ---------------------------------------------------------------------------
  default_filter_template = flatten([
    for f in local.default_filter_definitions : [
      for s in f.sources : {
        name               = f.name
        filter_enabled     = true
        block_enabled      = true

        # APPLY INVERSION
        severity_threshold = lookup(local.severity_inverse_map, title(f.severity), title(f.severity))

        source             = s
      }
    ]
  ])

  # ---------------------------------------------------------------------------
  # 3. Default content filter object (if user passes none)
  # ---------------------------------------------------------------------------
  default_content_filter_object = {
    name       = "TDBaseFilter"
    mode       = "Asynchronous_filter"
    filters    = local.default_filter_template
    blocklists = []
  }

  # ---------------------------------------------------------------------------
  # 4. Merge user-provided filters with defaults
  # ---------------------------------------------------------------------------
  merged_content_filters = concat(
    [local.default_content_filter_object],
    try(var.content_filters, [])
  )

  # ---------------------------------------------------------------------------
  # 5. Final assembly: ensure defaults exist + apply inversion to user filters
  # ---------------------------------------------------------------------------
  all_filters = {
    for cf in local.merged_content_filters :
    cf.name => merge(
      cf,
      {
        filters = flatten([

          # USER FILTERS (apply severity inversion)
          [
            for uf in cf.filters : merge(
              uf,
              {
                severity_threshold = lookup(
                  local.severity_inverse_map,
                  uf.severity_threshold,
                  uf.severity_threshold
                )
              }
            )
          ],

          # ADD MISSING DEFAULT FILTERS
          [
            for df in local.default_filter_template :
            df if !(contains([for uf in cf.filters : uf.name], df.name))
          ]
        ])
      }
    )
  }
}
