#!/usr/bin/env pwsh

Write-Host "Testing Echo MCP Server" -ForegroundColor Green
Write-Host "======================" -ForegroundColor Green

# Function to send MCP request with proper initialization
function Invoke-MCPRequest {
    param(
        [string]$Request
    )
    
    # Create temporary file with full MCP sequence
    $mcpSequence = @"
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test-client","version":"1.0.0"}}}
{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}
$Request
"@
    
    $tempFile = [System.IO.Path]::GetTempFileName()
    $mcpSequence | Out-File -FilePath $tempFile -Encoding UTF8
    
    try {
        $result = Get-Content $tempFile | python echo_server.py | ConvertFrom-Json
        return $result
    }
    finally {
        Remove-Item $tempFile -Force
    }
}

# Function to send multiple requests in sequence
function Invoke-MCPSequence {
    param(
        [string[]]$Requests
    )
    
    # Create full MCP sequence
    $mcpSequence = @(
        '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test-client","version":"1.0.0"}}}',
        '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'
    )
    $mcpSequence += $Requests
    
    $tempFile = [System.IO.Path]::GetTempFileName()
    $mcpSequence | Out-File -FilePath $tempFile -Encoding UTF8
    
    try {
        $results = Get-Content $tempFile | python echo_server.py
        return $results
    }
    finally {
        Remove-Item $tempFile -Force
    }
}

Write-Host "`n1. Testing Server Initialization" -ForegroundColor Yellow
Write-Host "--------------------------------" -ForegroundColor Yellow

$initRequest = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test-client","version":"1.0.0"}}}'
$initResult = Invoke-MCPRequest -Request $initRequest

if ($initResult.result) {
    Write-Host "✓ Server initialized successfully" -ForegroundColor Green
    Write-Host "  Server: $($initResult.result.serverInfo.name) v$($initResult.result.serverInfo.version)" -ForegroundColor Cyan
    Write-Host "  Protocol: $($initResult.result.protocolVersion)" -ForegroundColor Cyan
} else {
    Write-Host "✗ Server initialization failed" -ForegroundColor Red
    Write-Host "  Error: $($initResult.error.message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n2. Testing Tools List" -ForegroundColor Yellow
Write-Host "---------------------" -ForegroundColor Yellow

$toolsRequest = '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
$toolsResult = Invoke-MCPRequest -Request $toolsRequest

if ($toolsResult.result -and $toolsResult.result.tools) {
    Write-Host "✓ Tools listed successfully" -ForegroundColor Green
    foreach ($tool in $toolsResult.result.tools) {
        Write-Host "  Tool: $($tool.name)" -ForegroundColor Cyan
        Write-Host "    Description: $($tool.description)" -ForegroundColor Gray
        Write-Host "    Required params: $($tool.inputSchema.required -join ', ')" -ForegroundColor Gray
    }
} else {
    Write-Host "✗ Failed to list tools" -ForegroundColor Red
    if ($toolsResult.error) {
        Write-Host "  Error: $($toolsResult.error.message)" -ForegroundColor Red
    }
}

Write-Host "`n3. Testing Tool Execution" -ForegroundColor Yellow
Write-Host "-------------------------" -ForegroundColor Yellow

$testMessages = @("Hello from PowerShell!", "Testing MCP integration", "Echo server is working!")

foreach ($message in $testMessages) {
    $toolRequest = @"
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"echo_tool","arguments":{"message":"$message"}}}
"@
    
    $toolResult = Invoke-MCPRequest -Request $toolRequest
    
    if ($toolResult.result -and $toolResult.result.content) {
        Write-Host "✓ Tool executed successfully" -ForegroundColor Green
        Write-Host "  Input: $message" -ForegroundColor Cyan
        Write-Host "  Output: $($toolResult.result.content[0].text)" -ForegroundColor Cyan
    } else {
        Write-Host "✗ Tool execution failed" -ForegroundColor Red
        if ($toolResult.error) {
            Write-Host "  Error: $($toolResult.error.message)" -ForegroundColor Red
        }
    }
    Write-Host ""
}

Write-Host "4. Testing Resources List" -ForegroundColor Yellow
Write-Host "------------------------" -ForegroundColor Yellow

$resourcesRequest = '{"jsonrpc":"2.0","id":4,"method":"resources/list","params":{}}'
$resourcesResult = Invoke-MCPRequest -Request $resourcesRequest

if ($resourcesResult.result -and $resourcesResult.result.resources) {
    Write-Host "✓ Resources listed successfully" -ForegroundColor Green
    foreach ($resource in $resourcesResult.result.resources) {
        Write-Host "  Resource: $($resource.uri)" -ForegroundColor Cyan
        Write-Host "    Name: $($resource.name)" -ForegroundColor Gray
        Write-Host "    Description: $($resource.description)" -ForegroundColor Gray
    }
} else {
    Write-Host "✗ Failed to list resources" -ForegroundColor Red
    if ($resourcesResult.error) {
        Write-Host "  Error: $($resourcesResult.error.message)" -ForegroundColor Red
    }
}

Write-Host "`n5. Testing Resource Reading" -ForegroundColor Yellow
Write-Host "---------------------------" -ForegroundColor Yellow

$testUris = @("echo://test-message", "echo://powershell-test", "echo://mcp-integration")

foreach ($uri in $testUris) {
    $resourceRequest = @"
{"jsonrpc":"2.0","id":5,"method":"resources/read","params":{"uri":"$uri"}}}
"@
    
    $resourceResult = Invoke-MCPRequest -Request $resourceRequest
    
    if ($resourceResult.result -and $resourceResult.result.contents) {
        Write-Host "✓ Resource read successfully" -ForegroundColor Green
        Write-Host "  URI: $uri" -ForegroundColor Cyan
        Write-Host "  Content: $($resourceResult.result.contents[0].text)" -ForegroundColor Cyan
    } else {
        Write-Host "✗ Resource read failed" -ForegroundColor Red
        if ($resourceResult.error) {
            Write-Host "  Error: $($resourceResult.error.message)" -ForegroundColor Red
        }
    }
    Write-Host ""
}

Write-Host "6. Testing Error Handling" -ForegroundColor Yellow
Write-Host "------------------------" -ForegroundColor Yellow

# Test invalid tool name
$invalidToolRequest = '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"invalid_tool","arguments":{"message":"test"}}}'
$invalidToolResult = Invoke-MCPRequest -Request $invalidToolRequest

if ($invalidToolResult.error) {
    Write-Host "✓ Error handling works correctly" -ForegroundColor Green
    Write-Host "  Expected error for invalid tool: $($invalidToolResult.error.message)" -ForegroundColor Cyan
} else {
    Write-Host "✗ Error handling test failed" -ForegroundColor Red
}

# Test missing required parameter
$missingParamRequest = '{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"echo_tool","arguments":{}}}'
$missingParamResult = Invoke-MCPRequest -Request $missingParamRequest

if ($missingParamResult.error) {
    Write-Host "✓ Parameter validation works correctly" -ForegroundColor Green
    Write-Host "  Expected error for missing parameter: $($missingParamResult.error.message)" -ForegroundColor Cyan
} else {
    Write-Host "✗ Parameter validation test failed" -ForegroundColor Red
}

Write-Host "`n7. Performance Test" -ForegroundColor Yellow
Write-Host "------------------" -ForegroundColor Yellow

$requests = @()
for ($i = 1; $i -le 5; $i++) {
    $id = $i + 10
    $message = "Performance test message $i"
    $requests += "{`"jsonrpc`":`"2.0`",`"id`":$id,`"method`":`"tools/call`",`"params`":{`"name`":`"echo_tool`",`"arguments`":{`"message`":`"$message`"}}}}"
}

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$perfResults = Invoke-MCPSequence -Requests $requests
$stopwatch.Stop()

Write-Host "✓ Performance test completed" -ForegroundColor Green
Write-Host "  Executed 5 requests in $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Cyan
Write-Host "  Average: $([math]::Round($stopwatch.ElapsedMilliseconds / 5, 2))ms per request" -ForegroundColor Cyan

Write-Host "`n8. JSON Output Test" -ForegroundColor Yellow
Write-Host "-------------------" -ForegroundColor Yellow

$jsonRequest = '{"jsonrpc":"2.0","id":20,"method":"tools/call","params":{"name":"echo_tool","arguments":{"message":"JSON test with special chars: {key: value, number: 123}"}}}'
$jsonResult = Invoke-MCPRequest -Request $jsonRequest

if ($jsonResult.result -and $jsonResult.result.content) {
    Write-Host "✓ JSON handling works correctly" -ForegroundColor Green
    Write-Host "  Complex message processed successfully" -ForegroundColor Cyan
} else {
    Write-Host "✗ JSON handling test failed" -ForegroundColor Red
}

Write-Host "`n" + ("="*50) -ForegroundColor Green
Write-Host "All tests completed!" -ForegroundColor Green
Write-Host ("="*50) -ForegroundColor Green
