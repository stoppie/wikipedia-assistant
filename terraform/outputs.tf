output "mysql_connection_name" {
  description = "Endpoint for the Wiki Assistant Database Instance"
  value       = google_sql_database_instance.wiki_assistant_db.connection_name
}
