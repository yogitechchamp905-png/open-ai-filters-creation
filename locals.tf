locals {
  # ---------------------------------------------------------------------------
  # 1. Define all the base filters that should always exist
  #    (Each can apply to one or multiple sources)
  # ---------------------------------------------------------------------------
  default_filter_definitions = [
    { name = "Hate",            severity = "Medium", sources = ["Prompt", "Completion"] },
    { name = "Sexual",          severity = "Medium", sources = ["Prompt", "Completion"] },
    { name = "Violence",        severity = "Medium", sources = ["Prompt", "Completion"] },
    { name = "SelfHarm",       severity = "Medium", sources = ["Prompt", "Completion"] },
    { name = "Jailbreak",       severity = "High",   sources = ["Prompt"] },
    { name = "Indirect Attack", severity = "High",   sources = ["Prompt"] }
  ]

  # ---------------------------------------------------------------------------
  # 2. Generate default filter templates dynamically for each defined source
  # ---------------------------------------------------------------------------
  default_filter_template = flatten([
    for f in local.default_filter_definitions : [
      for s in f.sources : {
        name               = f.name
        filter_enabled     = true
        block_enabled      = true
        severity_threshold = title(f.severity)
        source             = s
      }
    ]
  ])

  # ---------------------------------------------------------------------------
  # 3. Define default content filter object (used if user passes none)
  # ---------------------------------------------------------------------------
  default_content_filter_object = {
    name       = "TDBaseFilter"
    mode       = "Asynchronous_filter"
    filters    = local.default_filter_template
    blocklists = [] # Keeps type consistency
  }

  # ---------------------------------------------------------------------------
  # 4. Merge user-provided content filters with defaults
  # ---------------------------------------------------------------------------
  merged_content_filters = concat(
    [local.default_content_filter_object],
    try(var.content_filters, [])
  )

  # ---------------------------------------------------------------------------
  # 5. Ensure all default filters exist even if user defines partial filters
  # ---------------------------------------------------------------------------
  all_filters = {
    for cf in local.merged_content_filters :
    cf.name => merge(
      cf,
      {
        filters = flatten([
          cf.filters,
          [
            for df in local.default_filter_template :
            df if !(contains([for uf in cf.filters : uf.name], df.name))
          ]
        ])
      }
    )
  }
}
