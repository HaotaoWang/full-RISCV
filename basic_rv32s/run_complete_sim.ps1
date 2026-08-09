# RT-Thread 完整仿真测试脚本 (PowerShell)
# 用途：运行完整仿真并持续监控输出

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " RT-Thread JALR 修复验证仿真" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 设置输出文件
$LOG_FILE = "rt_thread_complete_sim.log"
$RESULT_FILE = "jalr_test_result.txt"

# 清理旧文件
Remove-Item -Path $LOG_FILE -ErrorAction SilentlyContinue
Remove-Item -Path $RESULT_FILE -ErrorAction SilentlyContinue
Remove-Item -Path "sim.vvp" -ErrorAction SilentlyContinue

Write-Host "[$(Get-Date -Format 'HH:mm:ss')] 开始编译..." -ForegroundColor Yellow

# 编译命令
$compileCmd = @"
iverilog -g2012 -o sim.vvp `
  -I../verilog-axi/rtl `
  -Imodules/cache `
  testbenches/RV32_SoC_AXI_tb.v `
  RV32_SoC_AXI_Top.v `
  modules/RV32I46F_5SP_MMIO.v `
  modules/axi_clint.v `
  modules/axi_ram_init.v `
  modules/cache/dcache.v `
  modules/cache/dcache_axi.v `
  modules/cache/dcache_axi_axi.v `
  modules/cache/dcache_core.v `
  modules/cache/dcache_core_data_ram.v `
  modules/cache/dcache_core_tag_ram.v `
  modules/cache/dcache_if_pmem.v `
  modules/cache/dcache_mux.v `
  modules/cache/dcache_pmem_mux.v `
  modules/cache/icache.v `
  modules/cache/icache_data_ram.v `
  modules/cache/icache_tag_ram.v `
  ../verilog-axi/rtl/axi_interconnect.v `
  ../verilog-axi/rtl/arbiter.v `
  ../verilog-axi/rtl/priority_encoder.v `
  testbenches/BUFG.v 2>&1
"@

# 执行编译
Invoke-Expression $compileCmd | Tee-Object -FilePath "compile.log"

if ($LASTEXITCODE -ne 0) {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ❌ 编译失败！" -ForegroundColor Red
    Write-Host "查看 compile.log 了解详情" -ForegroundColor Red
    exit 1
}

Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ✅ 编译成功" -ForegroundColor Green
Write-Host ""
Write-Host "[$(Get-Date -Format 'HH:mm:ss')] 开始运行仿真..." -ForegroundColor Yellow
Write-Host "这将需要几分钟时间，请耐心等待..." -ForegroundColor Yellow
Write-Host "实时输出正在写入: $LOG_FILE" -ForegroundColor Yellow
Write-Host ""
Write-Host "提示: 可以按 Ctrl+C 停止仿真" -ForegroundColor Gray
Write-Host ""

# 运行仿真
$jalrDetected = $false
$jalCount = 0
$jalrCount = 0
$rtThreadDetected = $false

try {
    $process = Start-Process -FilePath "vvp" -ArgumentList "sim.vvp" -NoNewWindow -RedirectStandardOutput $LOG_FILE -PassThru

    # 监控输出
    $reader = [System.IO.StreamReader]::new($LOG_FILE)
    $startTime = Get-Date

    Write-Host "监控中... (每10秒更新一次)" -ForegroundColor Cyan

    while (!$process.HasExited) {
        Start-Sleep -Seconds 10

        $elapsed = (Get-Date) - $startTime
        $lines = Get-Content $LOG_FILE -Tail 50 -ErrorAction SilentlyContinue

        # 检查关键输出
        foreach ($line in $lines) {
            if ($line -match "JALR执行次数.*?(\d+)") {
                $jalrCount = [int]$matches[1]
                if ($jalrCount -gt 0 -and !$jalrDetected) {
                    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ✅ 检测到 JALR 执行！次数: $jalrCount" -ForegroundColor Green
                    $jalrDetected = $true
                }
            }

            if ($line -match "JAL执行次数.*?(\d+)") {
                $jalCount = [int]$matches[1]
            }

            if ($line -match "RT-Thread" -and !$rtThreadDetected) {
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ✅ 检测到 RT-Thread 输出！" -ForegroundColor Green
                $rtThreadDetected = $true
            }

            if ($line -match "WB_JALR") {
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ✅ 检测到 JALR 指令执行！" -ForegroundColor Green
            }
        }

        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] 运行中... 已用时: $($elapsed.ToString('mm\:ss'))" -ForegroundColor Gray
        Write-Host "  当前统计: JAL=$jalCount, JALR=$jalrCount" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "仿真进程已结束" -ForegroundColor Yellow

} catch {
    Write-Host "错误: $_" -ForegroundColor Red
} finally {
    if ($reader) { $reader.Close() }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " 仿真完成" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 分析结果
Write-Host "提取关键结果..." -ForegroundColor Yellow
$lastLines = Get-Content $LOG_FILE -Tail 100 -ErrorAction SilentlyContinue

$jalrCount = 0
$jalCount = 0

foreach ($line in $lastLines) {
    if ($line -match "JALR执行次数.*?(\d+)") {
        $jalrCount = [int]$matches[1]
    }
    if ($line -match "JAL执行次数.*?(\d+)") {
        $jalCount = [int]$matches[1]
    }
}

Write-Host ""
Write-Host "========== 测试结果 ==========" -ForegroundColor Cyan
Write-Host "JAL 执行次数:  $jalCount" -ForegroundColor $(if ($jalCount -gt 0) { "Green" } else { "Yellow" })
Write-Host "JALR 执行次数: $jalrCount" -ForegroundColor $(if ($jalrCount -gt 0) { "Green" } else { "Red" })
Write-Host ""

if ($jalrCount -gt 0) {
    Write-Host "✅ JALR 修复成功！JALR 指令正常执行" -ForegroundColor Green
} else {
    Write-Host "❌ 警告: 未检测到 JALR 执行" -ForegroundColor Red
    Write-Host "   这可能意味着:" -ForegroundColor Yellow
    Write-Host "   1. 仿真时间太短，还没执行到 JALR" -ForegroundColor Yellow
    Write-Host "   2. 程序卡在了 JALR 之前" -ForegroundColor Yellow
    Write-Host "   3. JALR 仍然有问题" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "完整日志文件: $LOG_FILE" -ForegroundColor Cyan
Write-Host ""
Write-Host "查看最后50行输出:" -ForegroundColor Yellow
Get-Content $LOG_FILE -Tail 50

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
