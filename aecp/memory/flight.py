"""AECP Arrow Flight data plane: zero-copy inter-tool transport.

Run as a service (systemd unit aecp-arrow-flight):
    python -m aecp.memory.flight --serve --host 127.0.0.1 --port 8815

Protocol:
- do_get: tickets "last" -> last ingested table; "count" -> row count
- do_put: ingests an Arrow table, stores in-memory (the fabric handoff point)
"""

from __future__ import annotations

import argparse
import sys
import threading

import pyarrow as pa

try:
    import pyarrow.flight as fl
except ImportError as exc:  # pragma: no cover - pyarrow without flight extras
    raise SystemExit(
        "pyarrow.flight unavailable: install pyarrow with Flight support "
        f"(pip install pyarrow>=15): {exc}"
    ) from exc


class AecpFlightServer(fl.FlightServerBase):  # type: ignore[misc]
    def __init__(self, host: str = "127.0.0.1", port: int = 8815):
        location = f"grpc+tcp://{host}:{port}"
        super().__init__(location)
        self._host = host
        self._port = port
        self._lock = threading.Lock()
        self._table: pa.Table | None = None
        self._puts = 0

    def do_put(self, context, descriptor, reader, writer):  # type: ignore[no-untyped-def]
        table = reader.read_all()
        with self._lock:
            self._table = table
            self._puts += 1

    def do_get(self, context, ticket):  # type: ignore[no-untyped-def]
        token = ticket.ticket.decode("utf-8")
        with self._lock:
            if token == "count":
                n = self._table.num_rows if self._table is not None else 0
                t = pa.table({"count": pa.array([n], type=pa.int64())})
            elif token == "last" and self._table is not None:
                t = self._table
            else:
                raise fl.FlightUnavailableError("no table ingested", None)
        return fl.RecordBatchStream(t)

    def list_flights(self, context, criteria):  # type: ignore[no-untyped-def]
        yield self._flight("last")

    def _flight(self, token: str):  # type: ignore[no-untyped-def]
        return fl.FlightInfo(
            self._table.schema if self._table else pa.schema([]),
            fl.FlightEndpoint(
                ticket_for(token),
                [self._location],
            ),
            [],
            self._table.nbytes if self._table else 0,
            self._table.num_rows if self._table else 0,
        )

    @property
    def _location(self):  # type: ignore[no-untyped-def]
        return fl.Location.for_grpc_tcp(self._host, self._port)


def ticket_for(token: str):  # type: ignore[no-untyped-def]
    import pyarrow.flight as _fl

    return _fl.Ticket(token.encode("utf-8"))


def serve(host: str, port: int, max_threads: int = 4) -> None:
    server = AecpFlightServer(host, port)
    server.serve()


def client_roundtrip(host: str, port: int, rows: int = 100_000) -> dict[str, int]:
    """Client-side integration helper used by e2e and tests."""
    import pyarrow.flight as _fl

    client = _fl.FlightClient(f"grpc+tcp://{host}:{port}")
    table = pa.table(
        {"x": pa.array(range(rows), type=pa.float64()),
         "y": pa.array([i * 0.5 for i in range(rows)], type=pa.float64())}
    )
    writer, _ = client.do_put(_fl.FlightDescriptor.for_command(b"ingest"), table.schema)
    writer.write_table(table)
    writer.close()
    reader = client.do_get(ticket_for("last"))
    back = reader.read_all()
    return {"sent_rows": table.num_rows, "received_rows": back.num_rows}


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="AECP Arrow Flight server")
    ap.add_argument("--serve", action="store_true")
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=8815)
    ap.add_argument("--max-threads", type=int, default=4)
    ap.add_argument("--roundtrip-test", action="store_true")
    args = ap.parse_args(argv)
    if args.roundtrip_test:
        result = client_roundtrip(args.host, args.port)
        print(result)
        return 0
    if args.serve:
        serve(args.host, args.port, args.max_threads)
        return 0
    ap.print_help()
    return 2


if __name__ == "__main__":
    sys.exit(main())
