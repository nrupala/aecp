"""AECP architecture-as-code.

Two things live here:

1. The architectural blueprint (layers 0-6) transcribed from the AECP system
   definition, preserved as the canonical specification of the platform.
2. The operational deployment registry: every component AECP actually runs,
   with its layer, systemd unit name, ports, health endpoint, memory budget,
   and exec parameters. The launcher, CLI, and tests are all driven from this
   registry - there is no second hand-maintained topology list.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum

# =====================================================================
# 0-6. CANONICAL BLUEPRINT (from the AECP system definition)
# =====================================================================


class ComputeType(Enum):
    GPU_ARRAY = "GPU_ARRAY"
    NPU_ARRAY = "NPU_ARRAY"
    TPU_ARRAY = "TPU_ARRAY"
    BARE_METAL_CPU = "BARE_METAL_CPU"


@dataclass
class HardwareResources:
    compute_units: list[ComputeType]
    bus_routing: str = "Hardware Lanes / Direct PCIe Interconnect"
    energy_optimization: str = "39.7% Total Energy Savings vs. Virtualized/Container Daemons"


@dataclass
class OrchestrationConfig:
    component: str
    mechanism: str
    function: str = ""


MESOS_SPEC = OrchestrationConfig(
    component="Apache Mesos (RETIRED to Apache Attic - see ADR-0001)",
    mechanism="Original spec: bypasses Docker daemon; direct Linux kernel "
    "primitives (cgroups/namespaces) over host hardware. AECP implements this "
    "mechanism via the daemonless aecpd launcher on systemd cgroup slices.",
)

YARN_SPEC = OrchestrationConfig(
    component="Apache YARN Two-Tier Scheduling",
    mechanism="Resource scheduling across hardware lanes for heavy analytical "
    "workloads (bare-metal CPU, NPU, TPU arrays).",
    function="Orchestrates hardware lanes for heavy analytical workloads "
    "across bare-metal CPU, NPU, & TPU arrays. Optional heavy-analytics lane "
    "(ADR-0001); not part of the single-node reference model.",
)


@dataclass
class DecoupledStorageLayer:
    object_vault: str = "Apache Ozone Object Vaults"
    object_vault_desc: str = (
        "Redundant object store; scales past billions of files without memory saturation."
    )
    table_format: str = "Apache Iceberg Tables"
    table_format_desc: str = (
        "High-performance ACID tables, snapshot freezing, & automated migration "
        "to cold Ozone blocks."
    )


@dataclass
class StreamingFabricMetrics:
    sustained_ingestion: str = "315,000 Messages Per Second (spec target)"
    cpu_efficiency: str = "18.4% lower CPU utilization than virtualized alternatives"
    transit_delay: str = "4.2 Millisecond Transit Delay (spec target)"


@dataclass
class RealTimeStreamingFabric:
    pubsub_engine: str = "Apache Pulsar (Ingests pipelines from logs)"
    stream_processor: str = "Apache Flink (Stateful, sub-second continuous processing)"
    metrics: StreamingFabricMetrics = field(default_factory=StreamingFabricMetrics)


@dataclass
class MemoryPlaneMetrics:
    time_complexity: str = "O(1) Mathematical Complexity for memory transit"
    peak_throughput: str = "92.4 GB/SEC Peak Throughput (Arrow zero-copy buffers)"


@dataclass
class ZeroCopyMemoryPlane:
    fabric: str = "Apache Arrow Memory Fabric"
    transfer_model: str = "O(1) transit by passing direct memory references between tools"
    optimization: str = "Elimination of the Serialization Tax via off-heap pinning"
    metrics: MemoryPlaneMetrics = field(default_factory=MemoryPlaneMetrics)


@dataclass
class AISearchMesh:
    neural_engine: str = "Neural adapter (SINGA lane where platform supports it, ADR-0002)"
    indexing_engine: str = "Apache Solr Unified Indexing (Lucene keyword + 512-dim kNN vector)"


@dataclass
class IntelligentInterfaces:
    notebook_and_dashboards: str = "Apache Zeppelin & Apache Superset"
    chatbot_gateway: str = "AECP Gateway: Zeppelin queries -> Solr kNN retrieval -> neural compose"
    remote_access: str = "Apache Guacamole clientless HTML5 terminal access"


@dataclass
class ApacheEnterpriseComputingPlatform:
    name: str = "AECP: The 100% Apache Enterprise Computing Platform"
    cross_layer_capability: str = "End-User Accessibility across all operational layers"
    layer_0_hardware: HardwareResources = field(
        default_factory=lambda: HardwareResources(
            compute_units=[ComputeType.BARE_METAL_CPU]
        )
    )
    layer_1_orchestration: dict[str, OrchestrationConfig] = field(
        default_factory=lambda: {"mesos": MESOS_SPEC, "yarn": YARN_SPEC}
    )
    layer_2_storage: DecoupledStorageLayer = field(default_factory=DecoupledStorageLayer)
    layer_3_streaming: RealTimeStreamingFabric = field(default_factory=RealTimeStreamingFabric)
    layer_4_memory_plane: ZeroCopyMemoryPlane = field(default_factory=ZeroCopyMemoryPlane)
    layer_5_ai_search: AISearchMesh = field(default_factory=AISearchMesh)
    layer_6_interfaces: IntelligentInterfaces = field(default_factory=IntelligentInterfaces)


# =====================================================================
# OPERATIONAL REGISTRY - the deployed reference model
# =====================================================================


class Layer(Enum):
    HARDWARE = 0
    ORCHESTRATION = 1
    STORAGE = 2
    STREAMING = 3
    MEMORY_PLANE = 4
    AI_SEARCH = 5
    INTERFACES = 6


@dataclass(frozen=True)
class Component:
    name: str
    layer: Layer
    unit: str
    ports: tuple[int, ...]
    health_url: str | None
    memory_max: str
    description: str


def _c(name: str, layer: Layer, unit: str, ports: tuple[int, ...], health: str | None,
       mem: str, desc: str) -> Component:
    return Component(name, layer, unit, ports, health, mem, desc)


COMPONENTS: dict[str, Component] = {
    # L3 streaming fabric
    "pulsar": _c("Apache Pulsar (standalone)", Layer.STREAMING, "aecp-pulsar.service",
                 (6650, 8091, 3181, 2181), "http://127.0.0.1:8091/admin/v2/brokers/health",
                 "1200M", "Pub/sub ingestion engine, broker+bookkeeper+zookeeper in one"),
    "flink-jm": _c("Apache Flink JobManager", Layer.STREAMING, "aecp-flink-jobmanager.service",
                   (8082, 6123), "http://127.0.0.1:8082/taskmanagers",
                   "640M", "Cluster head + REST"),
    "flink-tm": _c("Apache Flink TaskManager", Layer.STREAMING, "aecp-flink-taskmanager.service",
                   (6122,), None, "1280M", "Stateful streaming processing slots"),
    "flink-sqlgw": _c("Flink SQL Gateway (headless)", Layer.STREAMING, "aecp-flink-sql-gateway.service",
                      (8085,), "http://127.0.0.1:8085/v1/info",
                      "512M", "SQL submission endpoint for streaming jobs"),
    # L2 storage
    # L2 storage (Ozone 2.2 layout: SCM client RPC 9860, datanode RPC 9861,
    # block RPC 9863, web 9877; OM RPC 9862, web 9865, ratis 9872;
    # DN 19864/9856/9859/9882; S3G 9878; Recon 9888/9891)
    "ozone-scm": _c("Apache Ozone SCM", Layer.STORAGE, "aecp-ozone-scm.service",
                    (9860, 9861, 9863, 9877),
                    "http://127.0.0.1:9877/jmx?qry=Hadoop:service=SCMNode,name=*",
                    "640M", "Storage container manager"),
    "ozone-om": _c("Apache Ozone OM", Layer.STORAGE, "aecp-ozone-om.service",
                   (9862, 9865, 9872), "http://127.0.0.1:9865/jmx?qry=Hadoop:service=OzoneManager,name=*",
                   "640M", "Object store metadata manager"),
    "ozone-dn": _c("Apache Ozone DataNode", Layer.STORAGE, "aecp-ozone-datanode.service",
                   (19864, 9856, 9859, 9882), None, "768M", "Container storage"),
    "ozone-s3g": _c("Apache Ozone S3 Gateway", Layer.STORAGE, "aecp-ozone-s3g.service",
                    (9878,), "http://127.0.0.1:9878/",
                    "384M", "S3-compatible endpoint for Iceberg fileio"),
    "ozone-recon": _c("Apache Ozone Recon", Layer.STORAGE, "aecp-ozone-recon.service",
                      (9891, 9890), "http://127.0.0.1:9891/api/summary",
                      "384M", "Cluster observability"),
    # L4 memory plane
    "arrow-flight": _c("Arrow Flight data plane", Layer.MEMORY_PLANE, "aecp-arrow-flight.service",
                       (8815,), None, "384M", "Zero-copy inter-tool transport"),
    # L5 AI & search
    "solr": _c("Apache Solr", Layer.AI_SEARCH, "aecp-solr.service",
               (8983,), "http://127.0.0.1:8983/solr/aecp_docs/admin/ping?wt=json",
               "800M", "Lucene keyword + 512-dim kNN vector search"),
    # L6 interfaces
    "zeppelin": _c("Apache Zeppelin", Layer.INTERFACES, "aecp-zeppelin.service",
                   (8083,), "http://127.0.0.1:8083/#/",
                   "768M", "Multi-user development notebooks"),
    "superset": _c("Apache Superset", Layer.INTERFACES, "aecp-superset.service",
                   (8087,), "http://127.0.0.1:8087/health",
                   "1280M", "Geospatial BI dashboards"),
    "guacamole": _c("Apache Guacamole (Tomcat)", Layer.INTERFACES, "aecp-guacamole.service",
                    (8090,), "http://127.0.0.1:8090/guacamole/",
                    "640M", "Clientless HTML5 remote access webapp"),
    "guacd": _c("Apache Guacamole guacd", Layer.INTERFACES, "aecp-guacd.service",
                (4822,), None, "256M", "Native remote-desktop protocol daemon"),
    # gateway (L6/L5 bridge)
    "gateway": _c("AECP Gateway (RAG chatbot)", Layer.INTERFACES, "aecp-gateway.service",
                  (8847,), "http://127.0.0.1:8847/healthz",
                  "384M", "Zeppelin query interception -> Solr kNN -> neural compose"),
}

# Ports the launcher must not collide with on a shared host (verified on the
# reference box 2026-09-10: 8080 aetheris-core, 8090 free, 8192 opencode, 8830
# llama, 8835 llama-router, 8840 dashboard, 8888 oc-bridge, 9700 ai-shim,
# 8192/8081 code-server).
RESERVED_FOREIGN_PORTS = frozenset({8080, 8081, 8192, 8830, 8835, 8888, 9700, 22})


def deployment_components() -> dict[str, Component]:
    """Components started by the reference deployment, in start order."""
    order = [
        "pulsar", "flink-jm", "flink-tm",
        "ozone-scm", "ozone-om", "ozone-dn", "ozone-s3g", "ozone-recon",
        "solr", "arrow-flight", "gateway",
        "zeppelin", "superset", "guacd", "guacamole",
    ]
    return {n: COMPONENTS[n] for n in order}


def port_conflicts() -> list[str]:
    """Return port conflicts between AECP components and reserved ports."""
    conflicts: list[str] = []
    for name, comp in COMPONENTS.items():
        for p in comp.ports:
            if p in RESERVED_FOREIGN_PORTS:
                conflicts.append(f"{name}:{p}")
    return conflicts


def sla_targets() -> dict[str, float]:
    """Measurable SLA targets; e2e runs record achieved values against these."""
    return {
        "streaming_ingest_msgs_per_sec": 50000.0,
        "streaming_e2e_latency_ms_max": 2000.0,
        "memory_plane_arrow_min_gbps": 5.0,
        "memory_plane_slice_o1_max_ms": 1.0,
        "storage_snapshot_ops": 2.0,
        "aimesh_knn_top1_hit": 1.0,
        "gateway_rag_answer_ok": 1.0,
    }


if __name__ == "__main__":
    aecp_system = ApacheEnterpriseComputingPlatform()
    print(f"System Specification Loaded: {aecp_system.name}")
    print(f"Deployment components: {len(deployment_components())}")
    conflicts = port_conflicts()
    print(f"Port conflicts: {conflicts if conflicts else 'none'}")
