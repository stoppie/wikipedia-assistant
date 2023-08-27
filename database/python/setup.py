import mysql.connector
import sys


def setup_database(
    host: str,
    user: str,
    password: str,
    database_name: str,
    database_user: str,
    database_user_pwd: str,
) -> None:
    # Create the connection
    conn = mysql.connector.connect(host=host, user=user, password=password)

    cursor = conn.cursor()

    # 1. Create the database
    create_db_query = f"CREATE DATABASE {database_name};"
    cursor.execute(create_db_query)

    # 2. Create the user
    create_user_query = (
        f"CREATE USER '{database_user}'@'%' IDENTIFIED BY '{database_user_pwd}';"
    )
    cursor.execute(create_user_query)

    # 3. Grant privileges to the user for the database
    grant_privileges_query = f"GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, DROP ON {database_name}.* TO '{database_user}'@'%';"
    cursor.execute(grant_privileges_query)

    # 4. Flush privileges to ensure they are applied
    cursor.execute("FLUSH PRIVILEGES;")

    # Close the connection
    cursor.close()
    conn.close()


if __name__ == "__main__":
    if len(sys.argv) < 6:
        print(
            "Usage: python3 setup.py <DB_HOST> <ROOT_PASSWORD> <DB_NAME> <DB_USER> <DB_USER_PASSWORD>"
        )
        sys.exit(1)

    (
        _,
        DATABASE_HOST,
        ROOT_PASSWORD,
        DATABASE_NAME,
        DATABASE_USER,
        DATABASE_USER_PWD,
    ) = sys.argv

    ROOT_USER = "root"

    setup_database(
        DATABASE_HOST,
        ROOT_USER,
        ROOT_PASSWORD,
        DATABASE_NAME,
        DATABASE_USER,
        DATABASE_USER_PWD,
    )
    print("Database setup completed!")
