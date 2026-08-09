# RT-Thread Complete Simulation Script
# Simple version without complex monitoring

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " RT-Thread JALR Fix Verification" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$LOG_FILE = "rt_thread_sim.log"

Write-Host "Step 1: Compiling..." -ForegroundColor Yellow

# Compile
bash run_sim.sh > $LOG_FILE 2>&1

Write-Host "Simulation started. Check log file: $LOG_FILE" -ForegroundColor Green
Write-Host ""
Write-Host "Monitor progress with:" -ForegroundColor Yellow
Write-Host "  Get-Content $LOG_FILE -Wait -Tail 20" -ForegroundColor Gray
Write-Host ""
Write-Host "Or view full log:" -ForegroundColor Yellow
Write-Host "  Get-Content $LOG_FILE" -ForegroundColor Gray
Write-Host ""
