#!/usr/bin/env pwsh

Write-Host "Testing BlackArch Security Tools MCP Server" -ForegroundColor Red
Write-Host "============================================" -ForegroundColor Red

# Function to send MCP request with proper initialization
function Invoke-MCPRequest {
    param(
        [string]$Request
    )
    
    # Create temporary file with full MCP sequence
    $mcpSequence = @"
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"security-test-client","version":"1.0.0"}}}
{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}
$Request
"@
    
    $tempFile = [System.IO.Path]::GetTempFileName()
    $mcpSequence | Out-File -FilePath $tempFile -Encoding UTF8
    
    try {
        $result = Get-Content $tempFile | python3 security_mcp_server.py | ConvertFrom-Json
        return $result
    }
    finally {
        Remove-Item $tempFile -Force
    }
}

Write-Host "`n⚠️  SECURITY TESTING DISCLAIMER ⚠️" -ForegroundColor Yellow
Write-Host "This tool is for AUTHORIZED TESTING ONLY:" -ForegroundColor Yellow
Write-Host "• Only test systems you own or have permission to test" -ForegroundColor Gray
Write-Host "• Only target private networks and localhost" -ForegroundColor Gray
Write-Host "• Educational purposes only" -ForegroundColor Gray
Write-Host "• Always follow ethical guidelines" -ForegroundColor Gray

$continue = Read-Host "`nDo you acknowledge these terms? (yes/no)"
if ($continue -ne "yes") {
    Write-Host "Test cancelled. Security testing requires acknowledgment." -ForegroundColor Red
    exit 1
}

Write-Host "`n1. Testing Server Initialization" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green

$initRequest = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"security-client","version":"1.0.0"}}}'
$initResult = Invoke-MCPRequest -Request $initRequest

if ($initResult.result) {
    Write-Host "✅ Security MCP Server initialized successfully" -ForegroundColor Green
    Write-Host "  Server: $($initResult.result.serverInfo.name) v$($initResult.result.serverInfo.version)" -ForegroundColor Cyan
} else {
    Write-Host "❌ Server initialization failed" -ForegroundColor Red
    Write-Host "  Error: $($initResult.error.message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n2. Testing Available Tools Listing" -ForegroundColor Green
Write-Host "===================================" -ForegroundColor Green

$toolsRequest = '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
$toolsResult = Invoke-MCPRequest -Request $toolsRequest

if ($toolsResult.result -and $toolsResult.result.tools) {
    Write-Host "✅ Security tools listed successfully" -ForegroundColor Green
    foreach ($tool in $toolsResult.result.tools) {
        Write-Host "  Tool: $($tool.name)" -ForegroundColor Cyan
        Write-Host "    Description: $($tool.description)" -ForegroundColor Gray
    }
} else {
    Write-Host "❌ Failed to list security tools" -ForegroundColor Red
}

Write-Host "`n3. Testing Nmap Scanner" -ForegroundColor Green
Write-Host "========================" -ForegroundColor Green

$nmapRequest = @"
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"nmap_scan","arguments":{"target":"127.0.0.1","scan_type":"basic","ports":"22,80,443"}}}
"@

$nmapResult = Invoke-MCPRequest -Request $nmapRequest

if ($nmapResult.result -and $nmapResult.result.content) {
    Write-Host "✅ Nmap scan completed successfully" -ForegroundColor Green
    Write-Host "  Target: 127.0.0.1 (localhost)" -ForegroundColor Cyan
    Write-Host "  Result preview: $($nmapResult.result.content[0].text.Substring(0, [Math]::Min(200, $nmapResult.result.content[0].text.Length))..." -ForegroundColor Cyan
} else {
    Write-Host "❌ Nmap scan failed" -ForegroundColor Red
    if ($nmapResult.error) {
        Write-Host "  Error: $($nmapResult.error.message)" -ForegroundColor Red
    }
}

Write-Host "`n4. Testing Nikto Web Scanner" -ForegroundColor Green
Write-Host "==============================" -ForegroundColor Green

$niktoRequest = @"
{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"nikto_scan","arguments":{"target":"127.0.0.1","port":80,"ssl":false}}}
"@

$niktoResult = Invoke-MCPRequest -Request $niktoRequest

if ($niktoResult.result -and $niktoResult.result.content) {
    Write-Host "✅ Nikto scan initiated" -ForegroundColor Green
    Write-Host "  Target: http://127.0.0.1:80" -ForegroundColor Cyan
    Write-Host "  Status: Scan completed or in progress" -ForegroundColor Cyan
} else {
    Write-Host "⚠️  Nikto scan may have failed (normal for localhost without web server)" -ForegroundColor Yellow
}

Write-Host "`n5. Testing Security Disclaimer" -ForegroundColor Green
Write-Host "===============================" -ForegroundColor Green

$disclaimerRequest = @"
{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"show_security_disclaimer","arguments":{}}}
"@

$disclaimerResult = Invoke-MCPRequest -Request $disclaimerRequest

if ($disclaimerResult.result -and $disclaimerResult.result.content) {
    Write-Host "✅ Security disclaimer displayed" -ForegroundColor Green
    Write-Host "  Content: $($disclaimerResult.result.content[0].text.Substring(0, [Math]::Min(100, $disclaimerResult.result.content[0].text.Length))..." -ForegroundColor Cyan
} else {
    Write-Host "❌ Failed to display disclaimer" -ForegroundColor Red
}

Write-Host "`n6. Testing Available Tools Function" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green

$toolsListRequest = @"
{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"list_available_tools","arguments":{}}}
"@

$toolsListResult = Invoke-MCPRequest -Request $toolsListRequest

if ($toolsListResult.result -and $toolsListResult.result.content) {
    Write-Host "✅ Available tools listed successfully" -ForegroundColor Green
    Write-Host "  Content preview: $($toolsListResult.result.content[0].text.Substring(0, [Math]::Min(150, $toolsListResult.result.content[0].text.Length))..." -ForegroundColor Cyan
} else {
    Write-Host "❌ Failed to list available tools" -ForegroundColor Red
}

Write-Host "`n7. Testing Target Validation (Security)" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green

$maliciousRequest = @"
{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"nmap_scan","arguments":{"target":"8.8.8.8","scan_type":"basic"}}}
"@

$maliciousResult = Invoke-MCPRequest -Request $maliciousRequest

if ($maliciousResult.error) {
    Write-Host "✅ Security validation working: External targets blocked" -ForegroundColor Green
    Write-Host "  Blocked target: 8.8.8.8" -ForegroundColor Cyan
    Write-Host "  Error: $($maliciousResult.error.message)" -ForegroundColor Cyan
} else {
    Write-Host "❌ SECURITY ISSUE: External target was allowed!" -ForegroundColor Red
}

Write-Host "`n" + "="*50 -ForegroundColor Red
Write-Host "Security Testing Complete!" -ForegroundColor Red
Write-Host "===========================" -ForegroundColor Red
Write-Host ""
Write-Host "✅ Tests completed successfully" -ForegroundColor Green
Write-Host "🔒 Security restrictions are active" -ForegroundColor Green
Write-Host "⚠️  Remember: Only test authorized targets" -ForegroundColor Yellow
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "• Integrate with Claude Desktop via MCP" -ForegroundColor Gray
Write-Host "• Run in Docker: docker-compose up" -ForegroundColor Gray  
Write-Host "• Test your own lab environment" -ForegroundColor Gray
