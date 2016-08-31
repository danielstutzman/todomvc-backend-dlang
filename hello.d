import std.conv: to;
import std.stdio;
import core.stdc.stdlib: exit;
import std.string: toStringz;
import std.string: format;

extern (C) {
  struct PGconn {};

  PGconn *PQconnectdb(const char *conninfo);

  enum ConnStatusType {
    CONNECTION_OK,
    CONNECTION_BAD,
    /* Non-blocking mode only below here */

    /*
     * The existence of these should never be relied upon - they should only
     * be used for user feedback or similar purposes.
     */
    CONNECTION_STARTED,     /* Waiting for connection to be made.  */
    CONNECTION_MADE,      /* Connection OK; waiting to send.     */
    CONNECTION_AWAITING_RESPONSE,   /* Waiting for a response from the
                       * postmaster.      */
    CONNECTION_AUTH_OK,     /* Received authentication; waiting for
                   * backend startup. */
    CONNECTION_SETENV,      /* Negotiating environment. */
    CONNECTION_SSL_STARTUP,   /* Negotiating SSL. */
    CONNECTION_NEEDED     /* Internal state: connect() needed */
  };

  ConnStatusType PQstatus(const PGconn *conn);

  char *PQerrorMessage(const PGconn *conn);

  void PQfinish(PGconn *conn);

  struct PGresult {};

  PGresult *PQexec(PGconn *conn, const char *query);

  enum ExecStatusType {
    PGRES_EMPTY_QUERY = 0,    /* empty query string was executed */
    PGRES_COMMAND_OK,     /* a query command that doesn't return
                   * anything was executed properly by the
                   * backend */
    PGRES_TUPLES_OK,      /* a query command that returns tuples was
                   * executed properly by the backend, PGresult
                   * contains the result tuples */
    PGRES_COPY_OUT,       /* Copy Out data transfer in progress */
    PGRES_COPY_IN,        /* Copy In data transfer in progress */
    PGRES_BAD_RESPONSE,     /* an unexpected response was recv'd from the
                   * backend */
    PGRES_NONFATAL_ERROR,   /* notice or warning message */
    PGRES_FATAL_ERROR,      /* query failed */
    PGRES_COPY_BOTH,      /* Copy In/Out data transfer in progress */
    PGRES_SINGLE_TUPLE      /* single tuple from larger resultset */
  };

  ExecStatusType PQresultStatus(const PGresult *res);

  void PQclear(PGresult *res);

  int PQntuples(const PGresult *res);

  char *PQgetvalue(const PGresult *res, int tup_num, int field_num);
}

class MyException : Exception {
  this(string msg, string file = __FILE__, size_t line = __LINE__) {
    super(msg, file, line);
  }
}

void main() {
  try {
    doDatabaseConnectAndQuery();
  } catch (MyException e) {
    writefln("MyException: %s", e.msg);
    exit(1);
  }
}

void doDatabaseConnectAndQuery() {
  PGconn* conn = PQconnectdb("host=localhost dbname=todomvc");
  if (PQstatus(conn) != ConnStatusType.CONNECTION_OK) {
    stderr.writef("Connection to database failed: %s",
      to!string(PQerrorMessage(conn)));
    exit(1);
  }
  scope(exit) PQfinish(conn);

  doQuery(conn);
}

void doQuery(PGconn* conn) {
  immutable string sql = "SELECT * FROM todo_items ORDER BY id";
  PGresult* result = PQexec(conn, toStringz(sql));
  scope(exit) PQclear(result);

  if (PQresultStatus(result) != ExecStatusType.PGRES_TUPLES_OK) {
    throw new MyException(format("Error from SQL '%s': %s",
      sql, to!string(PQerrorMessage(conn))));
  }

  for (int rowNum = 0; rowNum < PQntuples(result); rowNum++) {
    immutable int id         = to!int(to!string(PQgetvalue(result, rowNum, 0)));
    immutable string title   =        to!string(PQgetvalue(result, rowNum, 1));
    immutable bool completed =        to!string(PQgetvalue(result, rowNum, 2)) == "t";

    writefln("Todo(id=%d, title='%s', completed=%s)", id, title, completed);
  }
}
