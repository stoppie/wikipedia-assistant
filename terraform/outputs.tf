output "db_ip_address" {
  description = "IP Address for the Wiki Assistant Database Instance"
  value       = google_sql_database_instance.wiki_assistant_db.ip_address[0].ip_address
}

output "sql_connector_hostname" {
  description = "Name of the Compute Instance used for SQL connections"
  value       = google_compute_instance.wiki_assistant_sql_connector.name
}
