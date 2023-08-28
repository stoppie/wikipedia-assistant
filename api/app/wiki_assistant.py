from fastapi import FastAPI, HTTPException, Depends, Query
import mysql.connector
import sqlparse
from pydantic import BaseModel
import subprocess
import logging
import datetime
import os

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configuration checks
PROJECT_ID = os.environ.get("PROJECT_ID")
SECRET_VERSION = os.environ.get("SECRET_VERSION")
DATABASE_HOSTNAME = os.environ.get("DATABASE_HOSTNAME")

missing_envs = [
    var
    for var, value in {
        "PROJECT_ID": PROJECT_ID,
        "SECRET_VERSION": SECRET_VERSION,
        "DATABASE_HOSTNAME": DATABASE_HOSTNAME,
    }.items()
    if not value
]

if missing_envs:
    raise EnvironmentError(f"Missing environment variables: {', '.join(missing_envs)}")


def set_private_ip():
    """Get the private IP from the gcloud command."""
    try:
        result = (
            subprocess.check_output(
                [
                    "gcloud",
                    "sql",
                    "instances",
                    "describe",
                    DATABASE_HOSTNAME,
                    "--format=value(ipAddresses.ipAddress)",
                ],
                stderr=subprocess.STDOUT,
            )
            .decode("utf-8")
            .strip()
        )

    except subprocess.CalledProcessError as e:
        logger.error(f"Error executing command: {e.output.decode('utf-8')}")
        raise HTTPException(
            status_code=500, detail="Failed to get database IP address."
        )

    os.environ["DATABASE_IP_ADDRESS"] = result


def get_database_connection():
    """Establish a connection to the database."""
    if not os.environ.get("DATABASE_IP_ADDRESS"):
        set_private_ip()

    try:
        conn = mysql.connector.connect(
            user="api_user",
            password=os.environ.get("MYSQL_PWD"),
            host=os.environ.get("DATABASE_IP_ADDRESS"),
            database="wiki_assistant",
        )

        return conn

    except mysql.connector.Error as e:
        logger.error(f"Error connecting to database: {e}")
        raise HTTPException(status_code=500, detail="Database connection error.")


def process_result(result: dict):
    for key, value in result.items():
        if isinstance(value, bytearray):
            result[key] = value.decode("utf-8")
        elif isinstance(value, datetime.datetime):
            result[key] = value.isoformat()
    return result


wikiapp = FastAPI()


class SQLQuery(BaseModel):
    query: str


@wikiapp.post("/execute-sql")
async def execute_sql(
    query: SQLQuery,
    conn: mysql.connector.MySQLConnection = Depends(get_database_connection),
):
    """Execute a SQL query on the database."""
    parsed = sqlparse.parse(query.query)

    if not parsed:
        raise HTTPException(status_code=400, detail="Invalid SQL query.")

    if len(parsed) > 1 or not all(stmt.get_type() == "SELECT" for stmt in parsed):
        raise HTTPException(status_code=400, detail="Only SELECT queries are allowed.")

    try:
        with conn.cursor(dictionary=True) as cursor:
            cursor.execute(query.query)
            results = cursor.fetchall()

        processed_results = [process_result(row) for row in results]

    except mysql.connector.Error as err:
        logger.error(f"Database error: {err}")
        raise HTTPException(status_code=500, detail="Database error.")

    finally:
        conn.close()

    return {"result": processed_results}


@wikiapp.get("/outdated-page")
async def get_outdated_page(
    category: str = Query(
        ..., description="The category to fetch the most outdated page for."
    ),
    conn: mysql.connector.MySQLConnection = Depends(get_database_connection),
):
    """Return the most outdated page for a given category."""
    try:
        with conn.cursor(dictionary=True) as cursor:
            cursor.execute(
                "SELECT * FROM categoryoutdated WHERE category = %s",
                (category.encode("utf-8"),),
            )
            result = cursor.fetchone()

        if not result:
            raise HTTPException(
                status_code=404,
                detail=f"No outdated page found for category: {category}",
            )

        processed_result = process_result(result)

    except mysql.connector.Error as err:
        logger.error(f"Database error: {err}")
        raise HTTPException(status_code=500, detail="Database error.")

    finally:
        conn.close()

    return {"result": processed_result}
