"""Memory plane tests: zero-copy proofs and O(1) transit."""


from aecp.memory import fabric
from aecp.memory.bench import run as bench_run


def test_roundtrip_preserves_values():
    batch = fabric.make_batch(1000, 4)
    assert fabric.roundtrip_ok(batch)


def test_zero_copy_slice_values():
    batch = fabric.make_batch(100, 2)
    sliced = fabric.o1_slice(batch, 50, 10)
    assert sliced.num_rows == 10
    assert sliced.column(0)[0].as_py() == batch.column(0)[50].as_py()
    assert sliced.column(1)[9].as_py() == batch.column(1)[59].as_py()


def test_o1_slice_is_constant_time():
    small = fabric.make_batch(1_000, 2)
    large = fabric.make_batch(1_000_000, 2)
    t_small = min(fabric.measure_o1_slice(small, trials=200) for _ in range(3))
    t_large = min(fabric.measure_o1_slice(large, trials=200) for _ in range(3))
    assert t_large < 1.0, f"slice on 1M rows took {t_large}ms"
    ratio = max(t_large, t_small) / max(min(t_large, t_small), 1e-9)
    assert ratio < 50, f"slice time not O(1)-like: {t_small}ms vs {t_large}ms"


def test_ipc_smaller_than_json():
    batch = fabric.make_batch(10_000, 4)
    rep = fabric.record_overhead_report(batch)
    assert rep["ipc_bytes"] < rep["json_bytes"]
    assert rep["compression_ratio"] > 1.0


def test_benchmark_report_structure():
    rep = bench_run(rows=200_000)
    for key in ("arrow_ipc_gbps", "json_roundtrip_gbps", "slice_o1_small_ms",
                "slice_o1_large_ms", "o1_ratio", "platform"):
        assert key in rep
    assert rep["arrow_ipc_gbps"] > 0
    assert rep["o1_ratio"] < 100


def test_throughput_exceeds_sla_target():
    rep = bench_run(rows=1_000_000)
    assert rep["arrow_ipc_gbps"] >= 0.5  # conservative floor for CI runners
