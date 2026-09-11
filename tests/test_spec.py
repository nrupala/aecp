"""Spec integrity tests: registry, blueprint, ports, SLA targets."""

from aecp.spec import (
    COMPONENTS,
    ApacheEnterpriseComputingPlatform,
    Layer,
    deployment_components,
    port_conflicts,
    sla_targets,
)


def test_blueprint_loads():
    aecp = ApacheEnterpriseComputingPlatform()
    assert aecp.name.startswith("AECP:")
    assert aecp.layer_3_streaming.pubsub_engine.startswith("Apache Pulsar")
    assert aecp.layer_4_memory_plane.fabric.startswith("Apache Arrow")
    assert aecp.layer_2_storage.object_vault.startswith("Apache Ozone")


def test_all_layers_deployed_or_realized():
    layers = {c.layer for c in COMPONENTS.values()}
    assert Layer.HARDWARE not in layers  # L0 is reserved/spec, not a service
    services = {
        Layer.STORAGE, Layer.STREAMING,
        Layer.MEMORY_PLANE, Layer.AI_SEARCH, Layer.INTERFACES,
    }
    missing = services - layers
    assert not missing, f"layers without deployed components: {missing}"
    # L1 ORCHESTRATION is realized by the aecp.slice cgroup contract (ADR-0001),
    # verified by the launcher contract tests (test_units.py).


def test_100_percent_apache_names():
    names = " ".join(c.name for c in COMPONENTS.values())
    assert "Apache Pulsar" in names
    assert "Apache Flink" in names
    assert "Apache Ozone" in names
    assert "Apache Solr" in names
    assert "Apache Zeppelin" in names
    assert "Apache Superset" in names
    assert "Apache Guacamole" in names
    assert "Arrow" in names


def test_every_component_has_unit_and_memory_budget():
    for name, comp in COMPONENTS.items():
        assert comp.unit.startswith("aecp-"), name
        assert comp.memory_max.endswith("M"), name
        assert int(comp.memory_max[:-1]) >= 128, name
        assert comp.description, name


def test_no_port_conflicts():
    assert port_conflicts() == []


def test_deployment_order_covers_all_components():
    ordered = deployment_components()
    assert set(ordered) == set(COMPONENTS)
    assert list(ordered)[0] == "pulsar"


def test_sla_targets_measurable():
    targets = sla_targets()
    for key in ("streaming_ingest_msgs_per_sec", "memory_plane_arrow_min_gbps",
                "memory_plane_slice_o1_max_ms", "storage_snapshot_ops",
                "aimesh_knn_top1_hit", "gateway_rag_answer_ok"):
        assert key in targets
        assert targets[key] > 0
