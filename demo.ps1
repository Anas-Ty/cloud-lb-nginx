function Benchmark-Cluster($Count = 10, $Path = "/") {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $results = 1..$Count | ForEach-Object { curl.exe -s "http://localhost:8080$Path" }
    $sw.Stop()
    $results | ForEach-Object { Write-Host "  $_" }
    Write-Host "`nTotal time for $Count requests: $($sw.ElapsedMilliseconds) ms (Avg: $([math]::Round($sw.ElapsedMilliseconds / $Count, 2)) ms/req)" -ForegroundColor Cyan
}

while ($true) {
    Write-Host "`n==========================================" -ForegroundColor Yellow
    Write-Host " CLOUD LOAD BALANCING LAB (NGINX + DOCKER)" -ForegroundColor Yellow
    Write-Host "==========================================" -ForegroundColor Yellow
    Write-Host "1. [Centralized] Static: Round Robin (Default)"
    Write-Host "2. [Centralized] Static: Weighted Round Robin (3:1:1)"
    Write-Host "3. [Centralized] Static: IP Hash (Sticky Sessions)"
    Write-Host "4. [Centralized] Dynamic: Least Connections (Slow + Fast Mix)"
    Write-Host "5. [Centralized] Fault Tolerance Test (Stop web2)"
    Write-Host "6. [Distributed] Multi-LB Architecture (Edge -> LB-A & LB-B)"
    Write-Host "7. [Distributed] High Availability Test (Crash LB-Zone-A!)"
    Write-Host "0. Exit"
    $choice = Read-Host "`nSelect scenario (0-7)"

    switch ($choice) {
        "1" {
            docker compose -f docker-compose.dist.yml down 2>$null
            Copy-Item "nginx\1_round_robin.conf" "nginx\active.conf" -Force
            docker compose up -d
            docker exec nginx-lb nginx -s reload
            Benchmark-Cluster 9
        }
        "2" {
            Copy-Item "nginx\2_weighted.conf" "nginx\active.conf" -Force
            docker exec nginx-lb nginx -s reload
            Benchmark-Cluster 10
        }
        "3" {
            Copy-Item "nginx\3_ip_hash.conf" "nginx\active.conf" -Force
            docker exec nginx-lb nginx -s reload
            Benchmark-Cluster 6
        }
        "4" {
            Copy-Item "nginx\4_least_conn.conf" "nginx\active.conf" -Force
            docker exec nginx-lb nginx -s reload
            Write-Host "Launching 2 slow requests (2s each) + 4 fast requests..." -ForegroundColor Magenta
            Start-Job { curl.exe -s "http://localhost:8080/slow" } | Out-Null
            Start-Job { curl.exe -s "http://localhost:8080/slow" } | Out-Null
            Start-Sleep -Milliseconds 300
            Benchmark-Cluster 4 "/"
        }
        "5" {
            Write-Host "Stopping web2 container..." -ForegroundColor Red
            docker stop web2 | Out-Null
            Benchmark-Cluster 6
            Write-Host "Restarting web2..." -ForegroundColor Green
            docker start web2 | Out-Null
        }
        "6" {
            Write-Host "Switching to Distributed Multi-LB Architecture..." -ForegroundColor Green
            docker compose down 2>$null
            docker compose -f docker-compose.dist.yml up -d
            Start-Sleep -Seconds 2
            Benchmark-Cluster 9
        }
        "7" {
            Write-Host "Crashing lb-zone-a! Traffic automatically fails over to lb-zone-b..." -ForegroundColor Red
            docker stop lb-zone-a | Out-Null
            Benchmark-Cluster 6
            Write-Host "Recovering lb-zone-a..." -ForegroundColor Green
            docker start lb-zone-a | Out-Null
        }
        "0" { break }
    }
}
