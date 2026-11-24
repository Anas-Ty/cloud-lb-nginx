# Cloud Load Balancing Lab with NGINX & Docker

A containerized cloud infrastructure lab demonstrating **Layer 7 (HTTP) Reverse Proxy and Load Balancing** using **NGINX** and **Docker Compose**. This project compares **Centralized** and **Distributed** load-balancing architectures, **Static** and **Dynamic** traffic distribution algorithms, and **Fault Tolerance / High Availability** failover behaviors.

---

## Project Overview & Architecture

In cloud computing, load balancing distributes incoming client traffic across multiple backend compute nodes to optimize resource utilization, maximize throughput, minimize response latency, and eliminate single points of failure.

This repository implements two distinct cloud topologies over an isolated Docker bridge network (`cloud_net`):

### 1. Centralized Architecture (`docker-compose.yml`)
A single NGINX load balancer (`nginx-lb`) acts as the sole entry point on port `8080`, routing requests to three containerized Python backend servers (`web1`, `web2`, `web3`).
* **Advantage:** Minimal latency overhead and straightforward configuration.
* **Limitation:** The load balancer itself is a Single Point of Failure (SPOF).

```text
                        +-------------------+
                        |  Client (Port 8080)|
                        +---------+---------+
                                  |
                        +---------v---------+
                        |     nginx-lb      |
                        | (Centralized LB)  |
                        +----+----+----+----+
                             |    |    |
                 +-----------+    |    +-----------+
                 v                v                v
          +------------+   +------------+   +------------+
          |    web1    |   |    web2    |   |    web3    |
          |  (:5000)   |   |  (:5000)   |   |  (:5000)   |
          +------------+   +------------+   +------------+
2. Distributed Multi-LB Architecture (docker-compose.dist.yml)An edge routing tier (edge-router) distributes incoming traffic across two independent NGINX load balancers (lb-zone-a running least_conn and lb-zone-b running round-robin), simulating multi-zone cloud edge routing.Advantage: Eliminates the load balancer SPOF—crashing lb-zone-a leaves the application online via lb-zone-b.Limitation: Introduces an additional network hop and higher infrastructure footprint.Plaintext                        +-------------------+
                        | Client (Port 8080)|
                        +---------+---------+
                                  |
                        +---------v---------+
                        |    edge-router    |
                        +----+---------+----+
                             |         |
               +-------------+         +-------------+
               v                                     v
      +-----------------+                   +-----------------+
      |    lb-zone-a    |                   |    lb-zone-b    |
      |  (least_conn)   |                   |  (round-robin)  |
      +--------+--------+                   +--------+--------+
               |                                     |
               +------------------+------------------+
                                  |
                        +---------v---------+
                        |  web1, web2, web3 |
                        +-------------------+
Repository StructurePlaintextcloud-lb-nginx/
├── backend/
│   ├── Dockerfile                # Lightweight Python 3.11 Alpine image
│   └── app.py                    # HTTP backend returning hostname, IP, and /slow endpoint
├── nginx/
│   ├── 1_round_robin.conf        # Static: Sequential rotation (default)
│   ├── 2_weighted.conf           # Static: Capacity-weighted routing (3:1:1 ratio)
│   ├── 3_ip_hash.conf            # Static: Deterministic client IP hashing (sticky sessions)
│   ├── 4_least_conn.conf         # Dynamic: Routes to backend with fewest active connections
│   ├── edge_distributed.conf     # Distributed: Edge upstream across lb-zone-a & lb-zone-b
│   └── active.conf               # Active config mounted dynamically into nginx-lb
├── docker-compose.yml            # Centralized cluster definition
├── docker-compose.dist.yml       # Distributed multi-LB cluster definition
├── demo.ps1                      # Interactive PowerShell benchmark & scenario runner
└── README.md                     # Project documentation
How It Was BuiltBackend Microservice (backend/app.py & Dockerfile):Built on python:3.11-alpine using Python's built-in http.server on port 5000.Each container reads its SERVER_NAME environment variable (Backend-Server-1, Backend-Server-2, Backend-Server-3) and prints its internal container IP so routing decisions are immediately visible in terminal output.Includes a /slow endpoint (time.sleep(2)) to simulate heavy CPU/database workloads when benchmarking dynamic algorithms.Modular NGINX Configurations (nginx/*.conf):Configured NGINX (nginx:alpine) as an L7 reverse proxy (proxy_pass) with passive health checks (max_fails=2 fail_timeout=10s) and live metrics enabled via ngx_http_stub_status_module at /nginx_status.Separated each load-balancing algorithm into standalone .conf files so configurations can be hot-reloaded (nginx -s reload) with zero downtime.Interactive Benchmark Runner (demo.ps1):Automated cluster orchestration, hot-reloading, failure injection (docker stop), and millisecond latency benchmarking (System.Diagnostics.Stopwatch) into an interactive CLI menu.PrerequisitesDocker Desktop (Windows/macOS) or Docker Engine + Docker Compose v2 (Linux)PowerShell 5.1+ (for demo.ps1 on Windows) and curlHow to UseOption A: Interactive Demo & Benchmark Menu (Recommended on Windows)Clone the repository and navigate into the directory:PowerShellgit clone [https://github.com/](https://github.com/)<YOUR_USERNAME>/cloud-lb-nginx.git
cd cloud-lb-nginx
Allow local script execution for the current terminal session (if restricted) and launch the interactive menu:PowerShellSet-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\demo.ps1
Choose any scenario (1 through 7) to automatically deploy the topology, reload NGINX, execute requests, and measure latency:Menu OptionArchitectureAlgorithm / TestExpected Behavior1CentralizedRound Robin (Static)Rotates sequentially across Backend-Server-1 -> 2 -> 3.2CentralizedWeighted Round Robin (Static)Sends 60% of requests to web1 (weight=3) and 20% each to web2/web3 (weight=1).3CentralizedIP Hash (Static)Hashes the client IP so all requests from the same client stick to one backend.4CentralizedLeast Connections (Dynamic)Launches two 2-second /slow tasks and routes incoming fast requests to the idle server.5CentralizedBackend FailoverStops web2; NGINX detects the failure and routes 100% of traffic to web1 and web3.6DistributedMulti-LB Edge RoutingSpins up edge-router distributing traffic across lb-zone-a and lb-zone-b.7DistributedLB High Availability TestCrashes lb-zone-a; edge-router automatically fails over to lb-zone-b with zero downtime.Option B: Manual Docker Compose Execution (Windows / Linux / macOS)Start the Centralized Cluster:Bashdocker compose up -d --build
curl http://localhost:8080
View Live NGINX Connection Metrics:Bashcurl http://localhost:8080/nginx_status
Switch to the Distributed Multi-LB Cluster:Bashdocker compose down
docker compose -f docker-compose.dist.yml up -d
curl http://localhost:8080
Tear Down All Containers:Bashdocker compose down
docker compose -f docker-compose.dist.yml down