locals {
  db_parameter_group_parameters = [
    { name = "shared_preload_libraries", value = "auto_explain,pg_stat_statements,pg_hint_plan,pgaudit", apply_method = "pending-reboot" },
    { name = "log_statement", value = "ddl", apply_method = "pending-reboot" }, # Changed to pending-reboot
    { name = "log_connections", value = 1, apply_method = "immediate" },
    { name = "log_disconnections", value = 1, apply_method = "immediate" },
    { name = "log_lock_waits", value = 1, apply_method = "immediate" },
    { name = "log_min_duration_statement", value = 5000, apply_method = "immediate" },
    { name = "auto_explain.log_min_duration", value = 5000, apply_method = "immediate" },
    { name = "auto_explain.log_verbose", value = 1, apply_method = "immediate" },
    { name = "log_rotation_age", value = 1440, apply_method = "pending-reboot" },    # Changed to pending-reboot
    { name = "log_rotation_size", value = 102400, apply_method = "pending-reboot" }, # Changed to pending-reboot
    { name = "rds.log_retention_period", value = 10080, apply_method = "immediate" },
    { name = "random_page_cost", value = 1, apply_method = "immediate" },
    { name = "track_activity_query_size", value = 16384, apply_method = "pending-reboot" }, # Changed to pending-reboot
    { name = "idle_in_transaction_session_timeout", value = 7200000, apply_method = "immediate" },
    { name = "statement_timeout", value = 60000, apply_method = "immediate" },
    { name = "search_path", value = "\"$user\",public", apply_method = "immediate" }
  ]
}