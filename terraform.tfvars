content_filters = [
  {
    name = "TDBaseFilter-5"
    mode = "Asynchronous_filter"

    filters = [
      {
        name               = "Hate"
        severity_threshold = "Medium"
        source             = "Prompt"
      },
            {
        name               = "Hate"
        severity_threshold = "Medium"
        source             = "Completion"
      }
    ]

    blocklists = [
      {
        name        = "my-blocklist-1"
        description = "Custom blocklist 1"
        items = [
          {
            pattern     = "badword1"
            description = "Offensive term 1"
          },
          {
            pattern     = "\\b\\d{3}-\\d{2}-\\d{4}\\b"
            description = "SSN pattern"
          }
        ]
      },
      {
        name        = "my-blocklist-3"
        description = "Custom blocklist 2"
        items = [
          {
            pattern     = "badword2"
            description = "Offensive term 2"
          }
        ]
      }
    ]
  }
]

